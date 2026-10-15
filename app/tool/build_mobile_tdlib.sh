#!/usr/bin/env bash
# TDLib and its JSON interface are distributed under BSL-1.0.
set -euo pipefail
platform=${1:?Expected android or ios}
[[ "$platform" == android || "$platform" == ios ]] || exit 64
repo=$(cd "$(dirname "$0")/../.." && pwd -P)
work="$repo/.cache/native/mobile-build/$platform"
commit=c15d3f5a5de6e3ba5839822c451152e5e18bb700
mkdir -p "$work"
if [[ -n "${TGCINE_TDLIB_ARCHIVE:-}" ]]; then
  python3 - "$TGCINE_TDLIB_ARCHIVE" "$work/td" <<'PY'
import hashlib, sys, zipfile
from pathlib import Path
archive=Path(sys.argv[1]); destination=Path(sys.argv[2]).resolve()
if hashlib.sha256(archive.read_bytes()).hexdigest() != 'a11844b92c4da66119dd50e2d434ec987c1e04ee991a8ed74d6dd4b50360e667':
 raise SystemExit('Pinned TDLib archive checksum mismatch')
with zipfile.ZipFile(archive) as z:
 for item in z.infolist():
  relative=Path(*Path(item.filename).parts[1:])
  target=destination/relative
  if not target.resolve().is_relative_to(destination): raise SystemExit('Invalid source archive path')
  if item.is_dir(): target.mkdir(parents=True,exist_ok=True)
  else:
   target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(item))
print('Verified pinned TDLib source archive.')
PY
else
  if [[ ! -d "$work/td/.git" ]]; then
    git init "$work/td"
    git -C "$work/td" remote add origin https://github.com/tdlib/td.git
    git -C "$work/td" fetch --depth 1 origin "$commit"
    git -C "$work/td" checkout --detach FETCH_HEAD
  fi
  [[ "$(git -C "$work/td" rev-parse HEAD)" == "$commit" ]] || exit 1
fi
export TGCINE_NATIVE_WORK="$work"
if [[ "$platform" == android ]]; then
  sdk=${ANDROID_HOME:?Set ANDROID_HOME}
  ndk=${ANDROID_NDK_VERSION:-28.2.13676358}
  cd "$work/td/example/android"
  # Restrict the upstream OpenSSL loop to the two ABIs built by this job.
  python3 - <<'PY'
import os, hashlib
from pathlib import Path
p=Path('build-openssl.sh')
s=p.read_text().replace('for ABI in arm64-v8a armeabi-v7a x86_64 x86 ; do', 'for ABI in arm64-v8a x86_64 ; do')
archive=os.environ.get('TGCINE_OPENSSL_ARCHIVE')
if archive:
 if hashlib.sha512(Path(archive).read_bytes()).hexdigest() != '40f0b346a9a5cf4cb37f1ecebdc74750c39a95783710061bfac58964883b0831543ecee0aee9f747ea093781b13c58a543b0b935d222519e3cb19648d77a0276':
  raise SystemExit('Pinned OpenSSL archive checksum mismatch')
 s=s.replace('$WGET https://github.com/openssl/openssl/archive/refs/tags/$OPENSSL_VERSION.tar.gz', 'cp "$TGCINE_OPENSSL_ARCHIVE" "$OPENSSL_VERSION.tar.gz"')
p.write_text(s)
p=Path('build-tdlib.sh')
s=p.read_text()
p.write_text('\n'.join('TDLIB_INTERFACE_OPTION="-DTD_ANDROID_JSON=ON"' if line.startswith('TDLIB_INTERFACE_OPTION=') else line for line in s.splitlines())+'\n')
PY
  if [[ ! -d "$work/openssl" ]]; then
    bash build-openssl.sh "$sdk" "$ndk" "$work/openssl" openssl-3.6.5
  fi
  bash build-tdlib.sh "$sdk" "$ndk" "$work/openssl" c++_static JSON 23 'arm64-v8a x86_64'
  mkdir -p "$work/package/arm64-v8a" "$work/package/x86_64"
  cp tdlib/libs/arm64-v8a/libtdjson.so "$work/package/arm64-v8a/"
  cp tdlib/libs/x86_64/libtdjson.so "$work/package/x86_64/"
else
  [[ "$(uname -s)" == Darwin ]] || { echo 'iOS requires macOS and Xcode'; exit 1; }
  cd "$work/td/example/ios"
  python3 - <<'PY'
from pathlib import Path
for name in ('build.sh','build-openssl.sh'):
 p=Path(name);p.write_text(p.read_text().replace('platforms="macOS iOS watchOS tvOS visionOS"','platforms="iOS"'))
PY
  bash build-openssl.sh
  cmake -S "$work/td" -B "$work/generated" -DTD_GENERATE_SOURCE_FILES=ON
  cmake --build "$work/generated" -j 3
  bash build.sh
  # iOS embeds third-party native code as frameworks, not loose dylibs.
  python3 - <<'PY'
import os, plistlib, shutil, subprocess
from pathlib import Path
w=Path(os.environ['TGCINE_NATIVE_WORK'])
args=['xcodebuild','-create-xcframework']
for name in ('iOS','iOS-simulator'):
 f=w/'frameworks'/name/'tdjson.framework';f.mkdir(parents=True,exist_ok=True)
 shutil.copyfile(w/'td/example/ios/tdjson'/name/'lib/libtdjson.dylib', f/'tdjson')
 subprocess.run(['install_name_tool','-id','@rpath/tdjson.framework/tdjson',str(f/'tdjson')],check=True)
 (f/'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'tdjson','CFBundleIdentifier':'io.tgcine.tdjson','CFBundleName':'tdjson','CFBundlePackageType':'FMWK','CFBundleVersion':'1','CFBundleShortVersionString':'1.8.68','MinimumOSVersion':'15.0','CFBundleSupportedPlatforms':['iPhoneSimulator' if name.endswith('simulator') else 'iPhoneOS']}))
 args.extend(['-framework',str(f)])
out=w/'package/tdjson.xcframework'
out.parent.mkdir(parents=True,exist_ok=True)
if out.exists(): raise SystemExit('Preserve the existing package; use a fresh build workspace')
subprocess.run(args+['-output',str(out)],check=True)
PY
fi
python3 - "$platform" <<'PY'
import hashlib, json, os, sys
from pathlib import Path
p=Path(os.environ['TGCINE_NATIVE_WORK'])/'package'
entries=[{'path':f.relative_to(p).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted(p.rglob('*')) if f.is_file() and f.name!='manifest.json']
(p/'manifest.json').write_text(json.dumps({'sourceCommit':'c15d3f5a5de6e3ba5839822c451152e5e18bb700','platform':sys.argv[1],'files':entries},indent=2)+'\n')
PY
python3 "$repo/app/tool/install_mobile_tdlib.py" "$work/package" --check
