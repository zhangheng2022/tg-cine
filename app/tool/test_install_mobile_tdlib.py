import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from install_mobile_tdlib import COMMIT, validated_files


class ArtifactTests(unittest.TestCase):
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
