import hashlib
import json
import struct
import tempfile
import unittest
from pathlib import Path

from install_mobile_tdlib import COMMIT, validate_ios_binary, validated_files


class ArtifactTests(unittest.TestCase):
    def test_real_deployment_target_in_each_macho_slice(self):
        def thin(cpu, platform, minimum=15 << 16):
            return struct.pack('<8I', 0xfeedfacf, cpu, 0, 6, 1, 24, 0, 0) + struct.pack('<6I', 0x32, 24, platform, minimum, 0, 0)
        arm, intel = 0x100000c, 0x1000007
        self.assertEqual(validate_ios_binary(thin(arm, 2), 2), {arm})
        def fat(second):
            first = thin(arm, 7)
            return (struct.pack('>2I', 0xcafebabe, 2)
                    + struct.pack('>5I', arm, 0, 48, len(first), 0)
                    + struct.pack('>5I', intel, 0, 48 + len(first), len(second), 0)
                    + first + second)
        valid = fat(thin(intel, 7))
        self.assertEqual(validate_ios_binary(valid, 7), {arm, intel})
        for binary, platform in (
            (thin(arm, 2, (26 << 16) | (5 << 8)), 2),
            (fat(thin(intel, 7, 26 << 16)), 7),
            (valid, 2), (valid[:-1], 7), (b'not Mach-O', 2),
            (struct.pack('<8I', 0xfeedfacf, arm, 0, 6, 0, 0, 0, 0), 2),
        ):
            with self.subTest(platform=platform, size=len(binary)):
                with self.assertRaises(ValueError): validate_ios_binary(binary, platform)

    def test_provenance_hashes_and_paths(self):
        with tempfile.TemporaryDirectory(prefix='tg-cine-native-artifacts-') as directory:
            root = Path(directory)
            binary = root / 'arm64-v8a/libtdjson.so'
            binary.parent.mkdir()
            binary.write_bytes(b'not-a-shipping-library')
            entry = {'path': 'arm64-v8a/libtdjson.so', 'sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}
            manifest = {'sourceCommit': COMMIT, 'platform': 'android', 'files': [entry]}
            file = root / 'manifest.json'
            def write():
                file.write_text(json.dumps(manifest), encoding='utf-8')
            write()
            self.assertEqual(len(validated_files(root)), 1)
            entry['sha256'] = '0' * 64
            write()
            with self.assertRaises(ValueError): validated_files(root)
            entry['path'] = '../escape.so'
            write()
            with self.assertRaises(ValueError): validated_files(root)
            entry['path'] = 'C:/escape.so'
            write()
            with self.assertRaises(ValueError): validated_files(root)
            entry['path'] = 'arm64-v8a/libtdjson.so'
            manifest['sourceCommit'] = 'wrong'
            write()
            with self.assertRaises(ValueError): validated_files(root)


if __name__ == '__main__': unittest.main()
