import base64
import unittest
import tempfile
from pathlib import Path

from check_build_config import check_configuration


class BuildConfigurationTests(unittest.TestCase):
    def test_real_telegram_requires_native_framework_in_debug_and_release(self):
        definitions = ','.join(base64.b64encode(value).decode() for value in (
            b'TG_CINE_API_ID=100', b'TG_CINE_API_HASH=test-build-identifier',
        ))
        with tempfile.TemporaryDirectory() as directory:
            framework = Path(directory) / 'tdjson.xcframework'
            for mode in ('Debug', 'Profile', 'Release'):
                with self.assertRaises(ValueError): check_configuration(mode, definitions, framework)
            binary = framework / 'ios-arm64/tdjson.framework/tdjson'
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b'fixture-only')
            (framework / 'Info.plist').write_text('fixture-only')
            check_configuration('Debug', definitions, framework)
            check_configuration('Release', definitions, framework)
            partial = base64.b64encode(b'TG_CINE_API_ID=100').decode()
            with self.assertRaises(ValueError): check_configuration('Debug', partial, framework)
    def test_private_configuration_is_debug_only(self):
        definitions = base64.b64encode(b'TG_CINE_TELEGRAM_MOBILE_CONFIG=private-test-value').decode()
        check_configuration('Debug', definitions)
        for mode in ('Release', 'Profile', 'Release-production'):
            with self.assertRaises(ValueError): check_configuration(mode, definitions)
        check_configuration('Release', '')
        check_configuration('Release', base64.b64encode(b'OTHER=public-value').decode())
        check_configuration('Release', base64.b64encode(b'TG_CINE_TELEGRAM_CONFIG=').decode())


if __name__ == '__main__': unittest.main()
