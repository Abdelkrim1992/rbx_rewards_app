#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# RBX Rewards — iOS Pre-build Secret Generator
#
# Add this as a Run Script Build Phase in Xcode BEFORE "Compile Sources":
#   Xcode → Runner → Build Phases → + → New Run Script Phase
#   Shell: /bin/sh
#   Script: "${SRCROOT}/../scripts/ios_generate_secrets.sh"
#   Uncheck "Based on dependency analysis" (always run)
# ─────────────────────────────────────────────────────────────────────────────

set -e

# Navigate to Flutter project root (one level up from ios/)
PROJECT_ROOT="$(dirname "$SRCROOT")"

echo "▶  Generating app_secrets.dart from env.json..."
dart run "$PROJECT_ROOT/tool/generate_secrets.dart"
echo "✅ app_secrets.dart ready"
