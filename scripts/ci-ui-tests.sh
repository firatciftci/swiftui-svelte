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
  | awk 'NR == FNR { seconds[$2] = $1; next } { print (($0 in seconds) ? seconds[$0] : 30), $0 }' scripts/ui-test-durations.txt - \
  | LC_ALL=C sort -k1,1nr -k2,2 \
  | awk -v shard="$shard" -v count="$count" '
      {
        best = 1
        for (i = 2; i <= count; i++) if (load[i] < load[best]) best = i
        load[best] += $1
        if (best == shard) print $2
      }' > build/shard.txt

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
