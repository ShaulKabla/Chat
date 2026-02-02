#!/usr/bin/env bash
set -euo pipefail

# UI/UX dependencies for the premium Anonymous Chat experience (React Native stack).
# Run from the mobile app root when available.

if [[ -f package.json ]]; then
  echo "Installing UI/UX packages..."
  npm install lottie-react-native react-native-reanimated react-native-linear-gradient
  echo "Done."
else
  echo "No package.json found in current directory."
  echo "Run this script from your React Native project root."
  exit 1
fi
