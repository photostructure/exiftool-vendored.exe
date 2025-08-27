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
npm run update-exiftool  # Runs update-exiftool.js to download and install latest ExifTool

# Create a new release
npm run release
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

This module follows the ExifTool versioning with an additional patch number when needed:

### Automated Updates

1. **GitHub Actions** automatically checks for ExifTool updates every Monday at 6 AM UTC
   - Workflow: `.github/workflows/check-updates.yml`
   - Creates a PR if a new version is available
   - Tests are run automatically before creating the PR

2. **Manual Update Process**:
   - Run `npm run update-exiftool` to fetch and install the latest ExifTool binary
   - The script automatically updates package.json to match the ExifTool version with "-pre" suffix (e.g., "13.26.0-pre")
   - Commit the updated binary and package.json

### Release Process

1. Merge any automated update PRs
2. Go to the Actions tab on GitHub
3. Run the "Release" workflow
   - This removes the "-pre" suffix and publishes to npm
   - Creates a GitHub release with proper tagging
   - Uses GPG signing for commits and tags

### Version Numbering

- Versions match ExifTool's version with a patch number: `MAJOR.MINOR.PATCH`
- During development: version has "-pre" suffix (e.g., "13.26.0-pre")
- On release: "-pre" suffix is removed (e.g., "13.26.0")
- Additional patch releases can be made if needed (e.g., "13.26.1" for fixes)

## Important Notes

- This package is Windows-only (as declared in package.json `os` field)
- Do not modify files in the `bin/` directory manually - use `update-exiftool.js`
- The ExifTool binary and associated files in `bin/` are downloaded from official sources
- This module is used by the main `exiftool-vendored` package for Windows support
- Automation requires GitHub secrets:
  - `NPM_TOKEN` for publishing to npm
  - `GPG_PRIVATE_KEY`, `GPG_PASSPHRASE`, `GPG_FINGERPRINT` for signing
  - `GIT_USER_NAME`, `GIT_USER_EMAIL` for git config
- Tests must pass before any release
