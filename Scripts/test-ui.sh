#!/bin/bash
set -euo pipefail
mkdir -p build
xcrun simctl list devices available --json > build/simulators.json
simulator_id="${SIMULATOR_UDID:-$(python3 - <<'PY'
import json
from pathlib import Path
state = json.loads(Path('build/simulators.json').read_text())
for runtime, devices in state['devices'].items():
    if 'tvOS-27' in runtime:
        for device in devices:
            if device.get('isAvailable'):
                print(device['udid'])
                raise SystemExit
raise SystemExit('Install the tvOS 27 simulator runtime in Xcode before running this workflow.')
PY
)}"
# Complete the first simulator boot before XCTest starts its launch timeout.
xcrun simctl bootstatus "$simulator_id" -b
result="build/Workflow-$(date +%s).xcresult"
xcodebuild -project 'Living Room Cinema.xcodeproj' -scheme 'Living Room Cinema' -destination "platform=tvOS Simulator,id=$simulator_id" -derivedDataPath build/DerivedData test -maximum-concurrent-test-simulator-destinations 1 -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath "$result"
xcrun xcresulttool export attachments --path "$result" --output-path build/Screenshots
