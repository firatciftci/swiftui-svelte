#!/bin/sh
set -eu

shard=$1
count=$2
project="-project example/ios/SvelteHost.xcodeproj -scheme SvelteHost -destination id=$SIMULATOR_UDID -derivedDataPath build/derived"

xcodebuild test-without-building $project \
  -enumerate-tests \
  -test-enumeration-style flat \
  -test-enumeration-format json \
  -test-enumeration-output-path build/tests.json > build/enumerate.log
jq -r '.values[].enabledTests[].identifier | rtrimstr("()")' build/tests.json \
  | LC_ALL=C sort \
  | awk -v shard="$shard" -v count="$count" '(NR - 1) % count == shard - 1' > build/shard.txt

echo "Shard $shard of $count runs:"
cat build/shard.txt
if [ ! -s build/shard.txt ]; then
  echo "This shard has no tests." >&2
  exit 1
fi

set --
while read -r test; do set -- "$@" "-only-testing:$test"; done < build/shard.txt
xcodebuild test-without-building $project \
  -resultBundlePath build/UITests.xcresult \
  -retry-tests-on-failure \
  -test-iterations 2 \
  "$@"
