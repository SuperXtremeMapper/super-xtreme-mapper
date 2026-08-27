#!/bin/zsh
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
test_output="$(mktemp -d -t xtrememapping-unit-tests)"

printf 'Test artifacts: %s\n' "$test_output"

set +e
xcodebuild test \
  -project "$repo_root/XtremeMapping/SuperXtremeMapping.xcodeproj" \
  -scheme XtremeMapping \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$test_output/DerivedData" \
  -resultBundlePath "$test_output/UnitTests.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  -skip-testing:XtremeMappingUITests \
  -parallel-testing-enabled NO \
  "$@"
xcode_status=$?
set -e

result_bundle="$test_output/UnitTests.xcresult"
summary_file="$test_output/summary.json"

guard_result() {
  if [[ ! -d "$result_bundle" ]]; then
    printf 'No result bundle was produced (xcodebuild exit %d).\n' "$xcode_status" >&2
    return 1
  fi

  xcrun xcresulttool get test-results summary \
    --path "$result_bundle" \
    --format json > "$summary_file"

  /usr/bin/python3 - "$summary_file" "$xcode_status" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    summary = json.load(handle)

passed = int(summary.get("passedTests", 0))
failed = int(summary.get("failedTests", 0))
result = summary.get("result")
xcode_status = int(sys.argv[2])

print(f"Unit result: {result}; passed={passed}; failed={failed}")
if xcode_status != 0 or result != "Passed" or passed <= 0 or failed != 0:
    raise SystemExit(1)
PY
}

guard_result
