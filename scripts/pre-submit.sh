#!/usr/bin/env bash
# Fitti — walk the automatable half of the App Store checklist.
#
# Full checklist: the ios-app-store-readiness skill. This covers only what a
# script can actually verify; the rest needs eyes. Run it before every submission.
set -uo pipefail
cd "$(dirname "$0")/.."

INFO_PLIST="ios/Fitti/Info.plist"
ICON="ios/Fitti/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
MANIFEST="ios/Fitti/PrivacyInfo.xcprivacy"
SRC="ios/Fitti/Sources"

FAILED=0
pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$1"; }

echo "Fitti — pre-submission checks"
echo

echo "Privacy"
if [ -f "$MANIFEST" ]; then
  count=$(plutil -p "$MANIFEST" | grep -c NSPrivacyAccessedAPIType)
  pass "privacy manifest present, $count required-reason APIs declared"
else
  fail "no PrivacyInfo.xcprivacy — required since May 2024"
fi

# Guideline 5.1.1(ii): a purpose string must name the feature and the benefit.
# Anything short is almost certainly "We need your camera", which fails.
while IFS= read -r line; do
  key=$(echo "$line" | sed -E 's/^ *"([^"]+)".*/\1/')
  val=$(echo "$line" | sed -E 's/.*=> "(.*)"$/\1/')
  if [ "${#val}" -lt 40 ]; then
    fail "purpose string too vague (${#val} chars): $key"
  else
    pass "purpose string reads well: $key"
  fi
done < <(plutil -p "$INFO_PLIST" 2>/dev/null | grep 'UsageDescription')

# 5.1.1(v), mandatory since June 2022. Sign-out does not satisfy it.
grep -rqiE 'delete.?account' "$SRC" --include='*.swift' \
  && pass "account deletion exists in-app" \
  || fail "no account deletion — guideline 5.1.1(v)"

# 5.1.2(i), added Nov 2025: name the AI provider and get consent first.
grep -rqE 'AIConsent|Gemini|third-party AI' "$SRC" --include='*.swift' \
  && pass "third-party AI disclosure present" \
  || fail "no AI consent flow — guideline 5.1.2(i)"

echo
echo "Purchases"
grep -rqE 'AppStore\.sync|restorePurchases|restore' "$SRC/Features/PaywallView.swift" 2>/dev/null \
  && pass "Restore Purchases on the paywall" \
  || fail "no Restore Purchases — guideline 3.1.2"
grep -q "displayPrice" "$SRC/Features/PaywallView.swift" 2>/dev/null \
  && pass "paywall shows the real price from StoreKit" \
  || fail "paywall does not show price"

echo
echo "Build and assets"
[ "$(sips -g hasAlpha "$ICON" 2>/dev/null | awk '/hasAlpha/{print $2}')" = "no" ] \
  && pass "1024 icon has no alpha channel" \
  || fail "1024 icon has alpha — automatic upload rejection"
plutil -p "$INFO_PLIST" 2>/dev/null | grep -q ITSAppUsesNonExemptEncryption \
  && pass "export compliance declared" \
  || fail "ITSAppUsesNonExemptEncryption unset — questionnaire on every upload"
plutil -p "$INFO_PLIST" 2>/dev/null | grep -q 'NSAllowsArbitraryLoads" => 1' \
  && fail "App Transport Security disabled app-wide" \
  || pass "ATS not globally disabled"
grep -qiE '(beta|demo|trial)' <(plutil -p "$INFO_PLIST" 2>/dev/null | grep -i BundleDisplayName) \
  && fail "app name contains beta/demo/trial" \
  || pass "app name is clean"

echo
echo "Completeness"
# Guideline 2.1 — over 40% of unresolved review issues, per Apple.
if grep -rniE '\b(lorem ipsum|coming soon|TODO:|FIXME)\b' "$SRC" --include='*.swift' -l >/dev/null 2>&1; then
  warn "placeholder markers found in source — check none are user-visible"
else
  pass "no placeholder content"
fi
# App Review's network is IPv6-only with DNS64/NAT64, so an IPv4 literal fails
# there and nowhere else — including on every machine you tested on.
if grep -rnE '"[0-9]{1,3}(\.[0-9]{1,3}){3}"' "$SRC" --include='*.swift' 2>/dev/null \
   | grep -v '127\.0\.0\.1' | head -1 | grep -q .; then
  fail "hardcoded IPv4 literal — fails IPv6-only App Review"
else
  pass "no hardcoded IPv4 literals"
fi

echo
echo "Toolchain"
xcode=$(xcodebuild -version 2>/dev/null | head -1)
echo "  $xcode  (Xcode 26 / iOS 26 SDK required since April 2026)"

echo
echo "Still needs a human:"
cat <<'MANUAL'
  - demo account works from a clean device, backend awake, 2FA code in Notes
  - support + privacy URLs return 200 in a private window
  - privacy policy linked in App Store Connect AND in-app
  - screenshots show the app in use, not a login screen
  - EU DSA trader status verified (start weeks early)
  - age-rating questionnaire completed
  - iPad layout is not broken
MANUAL

echo
[ $FAILED -eq 0 ] && echo "All automatable checks passed." || echo "Fix the failures above before submitting."
exit $FAILED
