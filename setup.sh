#!/bin/bash
set -euo pipefail

echo "=== Claude Usage Menu Bar App - Setup ==="

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen via Homebrew..."
    brew install xcodegen
fi

echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ Done! Opening ClaudeUsage.xcodeproj..."
open ClaudeUsage.xcodeproj

echo ""
echo "Build & run with ⌘R in Xcode."
echo "The app will appear in your menu bar (no Dock icon)."
echo ""
echo "Prerequisites:"
echo "  - Claude Code installed (provides ~/.claude/.credentials.json)"
echo "  - macOS 14.0+"
