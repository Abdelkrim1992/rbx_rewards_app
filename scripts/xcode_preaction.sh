# ─────────────────────────────────────────────────────────────────────────────
# Xcode Build Scheme Pre-action Script
#
# USE THIS — NOT a Build Phase. Scheme Pre-actions are far more reliable.
#
# HOW TO ADD IN XCODE (one-time setup on Mac):
#   1. Open ios/Runner.xcworkspace in Xcode
#   2. Menu: Product → Scheme → Edit Scheme  (or ⌘<)
#   3. Left panel: click "Build"
#   4. Bottom left: expand the arrow → click "Pre-actions"
#   5. Click the "+" button → "New Run Script Action"
#   6. "Provide build settings from": select "Runner"
#   7. Paste the contents of this file into the script box
#   8. Close the scheme editor
#
# WHY THIS WORKS (unlike Build Phases):
#   - Runs BEFORE Xcode's build system starts — guaranteed
#   - Has access to $SRCROOT (Flutter project root)
#   - "Provide build settings from Runner" gives correct env
# ─────────────────────────────────────────────────────────────────────────────

#!/bin/sh
set -e

# ── Locate dart ───────────────────────────────────────────────────────────────
# Xcode strips PATH — we must find dart explicitly
DART=""

# Check common Flutter installation locations in order
for candidate in \
    "$HOME/development/flutter/bin/dart" \
    "$HOME/flutter/bin/dart" \
    "/opt/homebrew/bin/dart" \
    "/usr/local/bin/dart" \
    "$FVM_HOME/default/bin/dart" \
    "$HOME/fvm/default/bin/dart" \
    "$HOME/.pub-cache/bin/dart"
do
    if [ -x "$candidate" ]; then
        DART="$candidate"
        break
    fi
done

# Fallback: try which with common PATH extensions
if [ -z "$DART" ]; then
    export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.pub-cache/bin"
    DART=$(which dart 2>/dev/null || true)
fi

if [ -z "$DART" ]; then
    echo "warning: dart not found — app_secrets.dart will not be regenerated."
    echo "warning: Install Flutter and ensure 'dart' is in your PATH."
    exit 0  # Don't fail the build — use previously generated file
fi

# ── Run the generator ─────────────────────────────────────────────────────────
cd "$SRCROOT/.."  # Navigate to Flutter project root (one level up from ios/)
echo "▶ Generating app_secrets.dart (dart: $DART)"
"$DART" run tool/generate_secrets.dart
echo "✅ app_secrets.dart ready"
