#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin && "${GITHUB_ACTIONS:-}" == true ]] || {
    echo 'This entry point requires the native Mac Actions runner.' >&2;exit 1;
}
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
phase="${1:?Specify preflight, prepare, engine, build or seal}"
run_private() {
    label="$1";shift
    if "$@" > "$RUNNER_TEMP/meridian-$label.log" 2>&1; then
        printf '%s complete.\n' "$label"
    else
        printf '%s failed; diagnostic details will be encrypted.\n' "$label" >&2
        return 1
    fi
}
case "$phase" in
    preflight)
        uname -a
        sw_vers
        sysctl -n hw.memsize
        df -h "$PWD"
        DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer xcodebuild -version
        for tool in /usr/local/opt/openssl@3/bin/openssl /opt/homebrew/opt/openssl@3/bin/openssl; do
            [[ -x "$tool" ]] && "$tool" version
        done
        printf '%s\n' 'Preflight only: no private source or engine downloaded.'
        ;;
    prepare)
        run_private prepare bash "$root/source/Tools/Cloud/Mac-Prepare.sh"
        ;;
    engine)
        run_private engine python3 "$root/source/Tools/Cloud/Fetch-Mac-Engine.py"
        ;;
    build)
        run_private build bash "$root/source/Tools/Build-Mac-Dmg.sh"
        run_private smoke bash "$root/source/Tools/Cloud/Mac-Smoke.sh"
        ;;
    seal)
        export MERIDIAN_CI_ROOT="$root"
        python3 - <<'PY'
from pathlib import Path
import os
import tarfile
root = Path(os.environ['MERIDIAN_CI_ROOT'])
temp = Path(os.environ['RUNNER_TEMP'])
archive = temp / ('Meridian-' + os.environ['GITHUB_RUN_ID'] + '.tar.gz')
with tarfile.open(archive, 'w:gz', compresslevel=1) as output:
    for relative in ('Builds/Installers/macOS', 'Saved/DesktopBuildLogs'):
        folder = root / 'source' / relative
        if folder.is_dir():
            output.add(folder, arcname=relative)
    for log in temp.glob('meridian-*.log'):
        output.add(log, arcname='Diagnostics/' + log.name)
PY
        crypto=''
        for tool in /usr/local/opt/openssl@3/bin/openssl /opt/homebrew/opt/openssl@3/bin/openssl; do
            if [[ -x "$tool" ]]; then crypto="$tool";break;fi
        done
        [[ -n "$crypto" ]] || { echo 'OpenSSL 3 is required to export encrypted results.' >&2;exit 1; }
        input="$RUNNER_TEMP/Meridian-$GITHUB_RUN_ID.tar.gz"
        output="$RUNNER_TEMP/Meridian-$GITHUB_RUN_ID.tar.cms"
        "$crypto" cms -encrypt -binary -aes-256-gcm -outform DER \
            -in "$input" -out "$output" -recip "$root/recipient.crt" \
            -keyopt rsa_padding_mode:oaep -keyopt rsa_oaep_md:sha256
        shasum -a 256 "$output"
        printf '%s\n' 'Only the encrypted result is eligible for artifact upload.'
        ;;
    *) echo 'Unknown phase.' >&2;exit 2;;
esac
