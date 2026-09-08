#!/usr/bin/env bash
# Sharding can hide a test class: one not named in any shard simply never runs,
# and the suite still reports green. This fails instead.
set -euo pipefail
cd "$(dirname "$0")/.."

listed=$(grep -oE '^ +classes: .+' .github/workflows/ui-tests.yml | sed 's/.*classes: //' | tr ' ' '\n' | sort -u)
on_disk=$(grep -rhoE '^(final )?class [A-Za-z]+: XCTestCase' TrainrUITests | sed -E 's/(final )?class //; s/: XCTestCase//' | sort -u)

missing=$(comm -13 <(echo "$listed") <(echo "$on_disk"))
absent=$(comm -23 <(echo "$listed") <(echo "$on_disk"))

status=0
if [ -n "$missing" ]; then
  echo "These test classes are in no shard, so they never run:" >&2
  echo "$missing" >&2
  status=1
fi
if [ -n "$absent" ]; then
  echo "These shard entries name no test class:" >&2
  echo "$absent" >&2
  status=1
fi
[ "$status" -eq 0 ] && echo "Every UI test class is in exactly one shard."
exit "$status"
