"""Check private credentials and required TDLib artifacts for iOS builds."""
import base64
import os
import sys
from pathlib import Path


def check_configuration(configuration, definitions, framework=None):
    values = {}
    for definition in definitions.split(','):
        if not definition:
            continue
        decoded = base64.b64decode(definition, validate=True).decode('utf-8')
        key, separator, value = decoded.partition('=')
        if separator:
            values[key] = value
        if not configuration.lower().startswith('debug') and separator and value and key in ('TG_CINE_TELEGRAM_CONFIG', 'TG_CINE_TELEGRAM_MOBILE_CONFIG'):
            raise ValueError('Private Telegram configuration is allowed only in Debug builds')
    if any(values.get(key) for key in ('TG_CINE_API_ID', 'TG_CINE_API_HASH')):
        if not all(values.get(key) for key in ('TG_CINE_API_ID', 'TG_CINE_API_HASH')):
            raise ValueError('Telegram application configuration is incomplete')
        if framework is None or not (framework / 'Info.plist').is_file() or not list(framework.glob('*/tdjson.framework/tdjson')):
            raise ValueError('Telegram requires the verified TDLib XCFramework')


if __name__ == '__main__':
    try:
        framework = Path(__file__).resolve().parent.parent / 'ios/TDLib/Frameworks/tdjson.xcframework'
        check_configuration(sys.argv[1], os.environ.get('DART_DEFINES', ''), framework)
    except (ValueError, IndexError):
        print('Telegram build rejected: invalid/private configuration or required TDLib artifact missing.', file=sys.stderr)
        sys.exit(1)
