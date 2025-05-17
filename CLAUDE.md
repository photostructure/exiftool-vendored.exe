# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `exiftool-vendored.exe`, a Node.js module that provides the Windows distribution of ExifTool. It's a thin wrapper around the official Windows ExifTool installation (which includes a portable Perl launcher and Strawberry Perl).

The main entry point is `index.js`, which simply exports the path to the vendored exiftool.exe binary located in `bin/exiftool.exe`.

## Common Commands

```bash
# Run tests
npm test

# Format code
npm run prettier

# Update the vendored ExifTool binary to latest version
npm run update-exiftool  # Runs update.js to download and install latest ExifTool
```

## Architecture

- `index.js` - Main entry point that exports the path to the vendored ExifTool binary
- `update-exiftool.js` - Script that fetches the latest Windows ExifTool package from exiftool.org
  - Downloads the official Windows 64-bit zip package
  - Verifies SHA256 checksums
  - Extracts and installs the binary in the `bin/` directory
  - Updates package.json version to match ExifTool version
- `test/path-exists.js` - Simple test that verifies the exported path exists
- `verification.sh` - Script to verify the integrity of Oliver Betz's ExifTool package

## Development Workflow

This module follows the ExifTool versioning with an additional patch number when needed. When updating:

1. Run `npm run update-exiftool` to fetch and install the latest ExifTool binary
2. The script automatically updates package.json to match the ExifTool version (e.g., "13.26.0")
3. Commit the updated binary and package.json
4. Release using `release-it` (configured in package.json)

## Important Notes

- This package is Windows-only (as declared in package.json `os` field)
- Do not modify files in the `bin/` directory manually - use `update-exiftool.js`
- The ExifTool binary and associated files in `bin/` are downloaded from official sources
- This module is used by the main `exiftool-vendored` package for Windows support