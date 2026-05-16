#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/script"
# shellcheck source=app_metadata.sh
source "$SCRIPT_DIR/app_metadata.sh"

EVIDENCE_DIR="${EVIDENCE_DIR:-$ROOT_DIR/dist/e2e/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$EVIDENCE_DIR"
mkdir -p "$ROOT_DIR/dist/e2e"
ln -sfn "$EVIDENCE_DIR" "$ROOT_DIR/dist/e2e/latest"

cd "$ROOT_DIR"

cleanup() {
  defaults write "$BUNDLE_ID" showDockIcon -bool false >/dev/null 2>&1 || true
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

log_step() {
  printf '\n==> %s\n' "$1" | tee -a "$EVIDENCE_DIR/e2e.log"
}

run_logged() {
  local label="$1"
  shift
  log_step "$label"
  "$@" 2>&1 | tee "$EVIDENCE_DIR/${label// /_}.log"
}

assert_missing_legacy_docs() {
  log_step "legacy doc cleanup check"
  local unexpected=()
  for path in README.ja.md README.zh-CN.md CHANGELOG.md intro.html; do
    if [[ -e "$path" ]]; then
      unexpected+=("$path")
    fi
  done
  if (( ${#unexpected[@]} > 0 )); then
    printf 'unexpected legacy docs: %s\n' "${unexpected[*]}" | tee -a "$EVIDENCE_DIR/e2e.log"
    return 1
  fi
  printf 'legacy docs absent\n' | tee -a "$EVIDENCE_DIR/e2e.log"
}

assert_translation_pane_has_no_speak_action() {
  log_step "translation pane speak-action check"
  if grep -RIn "Speak" Sources/QuickLate/Views/CommandWorkspaceView.swift Sources/QuickLate/Views/TranscriptPaneView.swift >/tmp/quicklate-e2e-speak-grep.txt; then
    cat /tmp/quicklate-e2e-speak-grep.txt | tee -a "$EVIDENCE_DIR/e2e.log"
    return 1
  fi
  printf 'no Speak action in command workspace translation pane\n' | tee -a "$EVIDENCE_DIR/e2e.log"
}

assert_workspace_redundant_actions_absent() {
  log_step "workspace redundant action check"
  local violation_file="/tmp/quicklate-e2e-redundant-actions.txt"
  : >"$violation_file"

  if grep -RInE 'Button\(AppText\.(copy|floatingCaptions)' Sources/QuickLate/Views/TranscriptPaneView.swift >>"$violation_file"; then
    true
  fi
  if grep -RInE 'AppText\.liveTranslationWorkspace|viewModel\.session\.languageSummary' Sources/QuickLate/Views/CommandWorkspaceView.swift >>"$violation_file"; then
    true
  fi

  if [[ -s "$violation_file" ]]; then
    cat "$violation_file" | tee -a "$EVIDENCE_DIR/e2e.log"
    return 1
  fi
  printf 'redundant pane buttons and workspace title summary absent\n' | tee -a "$EVIDENCE_DIR/e2e.log"
}

assert_settings_owns_setup_controls() {
  log_step "settings owns setup controls check"
  if grep -RIn 'CollapsibleSetupRailView' Sources/QuickLate/Views/CommandWorkspaceView.swift >/tmp/quicklate-e2e-setup-rail.txt; then
    cat /tmp/quicklate-e2e-setup-rail.txt | tee -a "$EVIDENCE_DIR/e2e.log"
    return 1
  fi
  grep -q 'SettingsLink' Sources/QuickLate/Views/CommandWorkspaceView.swift
  grep -q 'SettingsProcessingEngine' Sources/QuickLate/Views/SettingsView.swift
  grep -q 'SettingsLanguageSection' Sources/QuickLate/Views/SettingsView.swift
  grep -q 'SettingsAssetAvailabilityRow' Sources/QuickLate/Views/SettingsView.swift
  printf 'workspace setup rail absent and settings entrypoint/sections present\n' | tee -a "$EVIDENCE_DIR/e2e.log"
}

probe_app() {
  local label="$1"
  local expected_policy="$2"
  local expected_window="$3"
  local ready_file="$4"

  run_logged "probe $label" \
    swift run QuickLateE2E probe \
      --app-name "$APP_NAME" \
      --bundle-id "$BUNDLE_ID" \
      --expect-policy "$expected_policy" \
      --expect-main-window "$expected_window" \
      --ready-file "$ready_file" \
      --expect-event statusItemInstalled \
      --timeout 12 \
      --report "$EVIDENCE_DIR/$label-probe.json"
}

run_logged "swift test" swift test
run_logged "swift build" swift build
assert_missing_legacy_docs
assert_translation_pane_has_no_speak_action
assert_workspace_redundant_actions_absent
assert_settings_owns_setup_controls

log_step "default menu-bar launch"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
defaults write "$BUNDLE_ID" showDockIcon -bool false
DEFAULT_READY_FILE="$EVIDENCE_DIR/default-ready.jsonl"
rm -f "$DEFAULT_READY_FILE"
QUICKLATE_E2E_READY_FILE="$DEFAULT_READY_FILE" "$SCRIPT_DIR/build_and_run.sh" --verify 2>&1 | tee "$EVIDENCE_DIR/default-launch.log"
probe_app default accessory absent "$DEFAULT_READY_FILE"

log_step "dock opt-in launch"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
defaults write "$BUNDLE_ID" showDockIcon -bool true
DOCK_READY_FILE="$EVIDENCE_DIR/dock-ready.jsonl"
rm -f "$DOCK_READY_FILE"
QUICKLATE_E2E_READY_FILE="$DOCK_READY_FILE" "$SCRIPT_DIR/build_and_run.sh" --verify 2>&1 | tee "$EVIDENCE_DIR/dock-launch.log"
probe_app dock regular present "$DOCK_READY_FILE"

log_step "bundle metadata check"
{
  /usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$ROOT_DIR/dist/$APP_NAME.app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$ROOT_DIR/dist/$APP_NAME.app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$ROOT_DIR/dist/$APP_NAME.app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$ROOT_DIR/dist/$APP_NAME.app/Contents/Info.plist"
  test -f "$ROOT_DIR/dist/$APP_NAME.app/Contents/Resources/MenuBarIcon.png"
  test -f "$ROOT_DIR/dist/$APP_NAME.app/Contents/Resources/QuickLateLogo.png"
  /usr/libexec/PlistBuddy -c 'Print :NSSystemAudioCaptureUsageDescription' "$ROOT_DIR/dist/$APP_NAME.app/Contents/Info.plist"
} | tee "$EVIDENCE_DIR/bundle-metadata.log"

defaults write "$BUNDLE_ID" showDockIcon -bool false
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

log_step "e2e complete"
printf 'evidence_dir=%s\n' "$EVIDENCE_DIR" | tee -a "$EVIDENCE_DIR/e2e.log"
