#!/usr/bin/env bash
# A hosted runner sometimes comes up with a simulator runtime installed but no
# device registered, and xcodebuild then fails with "Unable to find a device".
# This finds the device by name, creates it from the newest iOS runtime when it
# is missing, boots it, waits until it is really ready, and prints its UDID.
set -euo pipefail
name="${1:-iPhone 17 Pro}"

udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
found = [d for runtime in devices.values() for d in runtime if d["name"] == name and d.get("isAvailable", True)]
print(found[0]["udid"] if found else "")' "$name")

if [ -z "$udid" ]; then
  runtime=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r.get("isAvailable")]
if not runtimes: sys.exit("no iOS simulator runtime is installed on this runner")
runtimes.sort(key=lambda r: [int(n) for n in r["version"].split(".")])
print(runtimes[-1]["identifier"])')
  devicetype=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
name = sys.argv[1]
types = [t for t in json.load(sys.stdin)["devicetypes"] if t["name"] == name]
if not types: sys.exit(f"no simulator device type named {name!r}")
print(types[0]["identifier"])' "$name")
  echo "No '$name' simulator registered; creating one on $runtime" >&2
  udid=$(xcrun simctl create "$name" "$devicetype" "$runtime")
fi

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
echo "Simulator '$name' ready: $udid" >&2
echo "$udid"
