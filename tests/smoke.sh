#!/bin/bash
# Builds the app into a temporary folder and runs every check that needs
# neither a pad nor T3 Code. Nothing outside that folder is touched.
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/t3-micro2-smoke.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

export T3_MICRO_APP="$WORK/T3 Micro Bridge.app"
export T3_MICRO_SIGN=adhoc
export T3_MICRO_BUNDLE_ID=us.kdpa.t3-micro-bridge.smoke
BIN="$T3_MICRO_APP/Contents/MacOS/t3-micro-bridge"
PLIST="$T3_MICRO_APP/Contents/Info.plist"

step() { printf '%s\n' "smoke: $*"; }
fail() { printf '%s\n' "smoke: FAILED: $*" >&2; exit 1; }

step "build"
"$HERE/t3-micro2" build

step "the app is whole and signed"
[ -x "$BIN" ] || fail "no binary at $BIN"
plutil -lint "$PLIST" >/dev/null || fail "Info.plist is not valid"
codesign --verify "$T3_MICRO_APP" || fail "the signature does not verify"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" = "$T3_MICRO_BUNDLE_ID" ] || fail "wrong bundle identifier"

step "one version everywhere"
WANT=$(plutil -extract version raw -o - "$HERE/package.json")
[ "$("$BIN" --version)" = "$WANT" ] || fail "the binary says $("$BIN" --version), package.json says $WANT"
[ "$("$HERE/t3-micro2" version)" = "$WANT" ] || fail "t3-micro2 version is not $WANT"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" = "$WANT" ] || fail "Info.plist is not $WANT"

step "self-test"
"$BIN" --self-test

step "the command"
HELP=$("$HERE/t3-micro2" help)
case $HELP in *"t3-micro2 setup"*) ;; *) fail "help does not list setup" ;; esac
if "$HERE/t3-micro2" nonsense >/dev/null 2>&1; then fail "an unknown command must fail"; fi
if "$HERE/t3-micro2" setup --layer x >/dev/null 2>&1; then fail "setup --layer x must fail"; fi

step "passed"
