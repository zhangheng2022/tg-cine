"""Stage mobile TDLib artifacts after checking their pinned provenance and hashes."""
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path, PurePosixPath

COMMIT = 'c15d3f5a5de6e3ba5839822c451152e5e18bb700'
APP = Path(__file__).resolve().parent.parent


def validate_ios_binary(data, platform):
    """Check the actual deployment target in every pinned Mach-O slice."""
    if data[:4] == b'\xca\xfe\xba\xbe':
        if len(data) < 8: raise ValueError('Truncated universal Mach-O')
        count = struct.unpack_from('>I', data, 4)[0]
        if count != 2 or len(data) < 8 + count * 20:
            raise ValueError('Unexpected universal Mach-O slices')
        cpus = set()
        for index in range(count):
            cpu, _, offset, size, _ = struct.unpack_from('>5I', data, 8 + index * 20)
            if offset < 8 + count * 20 or size > len(data) - offset:
                raise ValueError('Invalid universal Mach-O bounds')
            actual = validate_ios_binary(data[offset:offset + size], platform)
            if actual != {cpu} or cpu in cpus: raise ValueError('Invalid universal Mach-O architecture')
            cpus.add(cpu)
        return cpus
    if len(data) < 32 or data[:4] != b'\xcf\xfa\xed\xfe':
        raise ValueError('Expected a 64-bit Mach-O library')
    _, cpu, _, kind, commands, size, _, _ = struct.unpack_from('<8I', data)
    if kind != 6 or cpu not in (0x1000007, 0x100000c) or size > len(data) - 32:
        raise ValueError('Invalid Mach-O library header')
    offset, targets = 32, []
    for _ in range(commands):
        if offset + 8 > 32 + size: raise ValueError('Truncated Mach-O command')
        command, length = struct.unpack_from('<2I', data, offset)
        if length < 8 or offset + length > 32 + size: raise ValueError('Invalid Mach-O command size')
        if command == 0x32:  # LC_BUILD_VERSION
            if length < 24: raise ValueError('Truncated build version')
            target, minimum = struct.unpack_from('<2I', data, offset + 8)
            if target != platform or minimum != 15 << 16:
                raise ValueError('TDLib must target iOS 15.0 for the matching platform')
            targets.append(minimum)
        offset += length
    if offset != 32 + size or len(targets) != 1: raise ValueError('Missing or duplicate Mach-O deployment target')
    return {cpu}


def validated_files(package):
    package = package.resolve(strict=True)
    manifest = json.loads((package / 'manifest.json').read_text(encoding='utf-8'))
    if manifest.get('sourceCommit') != COMMIT or manifest.get('platform') not in ('android', 'ios'):
        raise ValueError('TDLib provenance mismatch')
    entries = manifest.get('files', [])
    if not entries or len(entries) > 1000:
        raise ValueError('Invalid artifact list')
    paths = set()
    validated = []
    for entry in entries:
        relative = PurePosixPath(entry['path'])
        if relative.is_absolute() or '..' in relative.parts or '\\' in str(relative) or ':' in str(relative):
            raise ValueError('Artifact path escapes its package')
        if str(relative) in paths:
            raise ValueError('Duplicate artifact')
        paths.add(str(relative))
        source = package.joinpath(*relative.parts)
        if source.is_symlink() or not source.resolve(strict=True).is_relative_to(package):
            raise ValueError('Linked artifact is not supported')
        if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError('Artifact checksum mismatch')
        if manifest['platform'] == 'android':
            if len(relative.parts) != 2 or relative.parts[0] not in ('arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86') or relative.name != 'libtdjson.so':
                raise ValueError('Unexpected Android artifact')
            destination = APP / 'android/app/src/main/jniLibs' / str(relative)
        else:
            if relative.parts[0] != 'tdjson.xcframework':
                raise ValueError('Unexpected iOS artifact')
            if relative.name == 'tdjson':
                simulator = relative.parts[1] == 'ios-arm64_x86_64-simulator'
                expected = {0x1000007, 0x100000c} if simulator else {0x100000c}
                if validate_ios_binary(source.read_bytes(), 7 if simulator else 2) != expected:
                    raise ValueError('Missing iOS architecture')
            destination = APP / 'ios/TDLib/Frameworks' / str(relative)
        if not destination.resolve().is_relative_to(APP):
            raise ValueError('Destination escapes the app')
        validated.append((source, destination))
    if manifest['platform'] == 'ios' and 'tdjson.xcframework/Info.plist' not in paths:
        raise ValueError('XCFramework metadata missing')
    if manifest['platform'] == 'ios' and not all(
        f'tdjson.xcframework/{variant}/tdjson.framework/tdjson' in paths
        for variant in ('ios-arm64', 'ios-arm64_x86_64-simulator')
    ):
        raise ValueError('XCFramework device or simulator binary missing')
    return validated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package', type=Path)
    parser.add_argument('--check', action='store_true', help='Verify without staging')
    options = parser.parse_args()
    files = validated_files(options.package)
    if not options.check:
        for source, destination in files:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
    print(f'Verified {len(files)} native artifacts; staged={not options.check}.')


if __name__ == '__main__':
    main()
