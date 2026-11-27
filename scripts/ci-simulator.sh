#!/bin/sh
set -eu

case "$1" in
  start)
    mkdir -p build
    udid=$(xcrun simctl list devices available --json | jq -r '[.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.name | startswith("iPhone"))][0].udid')
    echo "Using simulator $udid"
    echo "SIMULATOR_UDID=$udid" >> "$GITHUB_ENV"
    nohup xcrun simctl bootstatus "$udid" -b > build/boot.log 2>&1 &
    ;;
  wait)
    xcrun simctl bootstatus "$SIMULATOR_UDID" -b
    ;;
  *)
    echo "Usage: $0 start|wait" >&2
    exit 64
    ;;
esac
