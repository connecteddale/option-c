#!/bin/bash
# Creates a proper macOS .app bundle from the Swift package build

set -e

APP_NAME="Option-C"
BUNDLE_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Clean previous bundle
rm -rf "${BUNDLE_DIR}"

# Create bundle structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Build release if needed
swift build -c release

# Copy executable
cp .build/release/OptionC "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp Sources/OptionC/Resources/Info.plist "${CONTENTS_DIR}/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Sign with persistent identity so macOS keeps accessibility permissions across rebuilds
codesign --force --sign "OptionC Dev" --deep "${BUNDLE_DIR}"

echo "Created ${BUNDLE_DIR}"
echo "Run with: open '${BUNDLE_DIR}'"
