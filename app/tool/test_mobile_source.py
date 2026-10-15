import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


@unittest.skipIf(os.name == 'nt', 'Source builder runs on Linux/macOS')
class MobileSourceTests(unittest.TestCase):
    def test_changed_source_archive_is_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory(prefix='tg-cine-source-') as directory:
            root = Path(directory)
            tool = root / 'app/tool/build_mobile_tdlib.sh'
            tool.parent.mkdir(parents=True)
            shutil.copyfile(Path(__file__).with_name('build_mobile_tdlib.sh'), tool)
            archive = root / 'changed.zip'
            archive.write_bytes(b'changed source must not be accepted')
            result = subprocess.run(
                ['bash', str(tool), 'android'],
                env={**os.environ, 'TGCINE_TDLIB_ARCHIVE': str(archive)},
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Pinned TDLib archive checksum mismatch', result.stderr)
            self.assertFalse((root / '.cache/native/mobile-build/android/td').exists())


if __name__ == '__main__':
    unittest.main()
