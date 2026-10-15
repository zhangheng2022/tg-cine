"""Stage mobile TDLib artifacts after checking their pinned provenance and hashes."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path, PurePosixPath

COMMIT = 'c15d3f5a5de6e3ba5839822c451152e5e18bb700'
APP = Path(__file__).resolve().parent.parent


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
            destination = APP / 'ios/TDLib/Frameworks' / str(relative)
        if not destination.resolve().is_relative_to(APP):
            raise ValueError('Destination escapes the app')
        validated.append((source, destination))
    if manifest['platform'] == 'ios' and 'tdjson.xcframework/Info.plist' not in paths:
        raise ValueError('XCFramework metadata missing')
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
