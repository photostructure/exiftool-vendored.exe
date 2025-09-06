# exiftool-vendored.exe - Windows ExifTool Distribution

**ALWAYS follow these instructions first and only fallback to additional search and context gathering if the information here is incomplete or found to be in error.**

This is `exiftool-vendored.exe`, a Node.js module that provides the Windows distribution of ExifTool. It's a thin wrapper around the official Windows ExifTool installation (which includes a portable Perl launcher and Strawberry Perl). The main entry point exports the path to the vendored `bin/exiftool.exe` binary.

## Working Effectively

### Initial Setup and Dependencies

- Install dependencies: `npm install --force` -- takes 15-30 seconds. NEVER CANCEL.
  - **IMPORTANT**: Use `--force` flag because this package is Windows-only (declared in package.json `os` field)
  - On Linux/macOS, the package installs but the ExifTool binary won't execute (this is expected)
- Verify installation: `node -e "console.log(require('./index.js'))"`
  - Should output the absolute path to `bin/exiftool.exe`

### Build and Test Commands

- Run tests: `npm test` -- takes <1 second. Tests only verify the exported path exists.
- Format code: `npm run prettier` -- takes <1 second. NEVER CANCEL.
- **NO BUILD STEP REQUIRED** - this package only manages a pre-compiled binary and exports its path.

### Update ExifTool Binary

- Check for updates: `npm run check-version` -- takes 5-30 seconds (requires internet). NEVER CANCEL.
- Update binary: `npm run update-exiftool` -- takes 30-120 seconds (downloads from exiftool.org). NEVER CANCEL.
  - Downloads Windows 64-bit zip package from Oliver Betz's distribution
  - Verifies SHA256 checksums automatically
  - Extracts and installs in `bin/` directory
  - Updates package.json version to match ExifTool version with "-pre" suffix

## Validation

### Core Functionality Testing

Always validate changes by running this complete test:

```bash
node -e "
const path = require('./index.js');
const fs = require('fs');
console.log('Exported path:', path);
console.log('File exists:', fs.existsSync(path));
console.log('Path ends with exiftool.exe:', path.endsWith('exiftool.exe'));
"
```

### Required Validation Steps

- ALWAYS run `npm test` after any changes - should complete in <1 second
- ALWAYS run `npm run prettier` before committing - should complete in <1 second
- ALWAYS verify the main export returns the correct path to `bin/exiftool.exe`
- Do NOT modify files in `bin/` directory manually - use `update-exiftool.js` script instead

## Platform Constraints

### Windows-Only Package

- This package is **Windows-only** by design (see package.json `os` field)
- On Linux/macOS: Use `npm install --force` to bypass OS restriction for development
- The ExifTool binary won't execute on non-Windows platforms (this is expected)
- CI/CD workflows run on Windows for actual functionality testing

### Cross-Platform Development

- Development and testing of the Node.js wrapper code works on all platforms
- Only the ExifTool binary execution is Windows-specific
- Use `--force` flag for npm commands when working on non-Windows systems

## File Structure

### Key Files

- `index.js` - Main entry point (3 lines: exports path to vendored ExifTool binary)
- `bin/exiftool.exe` - The vendored Windows ExifTool binary
- `bin/exiftool_files/` - Supporting Perl libraries and dependencies
- `test/path-exists.js` - Simple test that verifies exported path exists
- `update-exiftool.js` - Script to download and install latest ExifTool binary
- `check-version.js` - Script to check for ExifTool updates
- `lib/version-utils.js` - Utility functions for version management

### Do NOT Modify

- Never modify files in `bin/` directory manually
- Never modify the ExifTool binary or its supporting files
- Use `update-exiftool.js` script for all ExifTool updates

## Automation and CI/CD

### GitHub Actions Workflows

- `.github/workflows/build.yml` - Runs tests on Windows with Node.js 20, 22, 24
- `.github/workflows/check-updates.yml` - Checks for ExifTool updates every Monday 6 AM UTC
- Automated PRs are created when new ExifTool versions are available

### Release Process

1. Merge any automated update PRs
2. Go to the Actions tab on GitHub
3. Run the "Release" workflow manually
   - Removes "-pre" suffix from version
   - Publishes to npm
   - Creates GitHub release with proper tagging

### Version Management

- Versions match ExifTool's version with a patch number: `MAJOR.MINOR.PATCH`
- During development: version has "-pre" suffix (e.g., "13.34.1-pre")
- On release: "-pre" suffix is removed (e.g., "13.34.1")

## Dependencies and Security

### Internet Requirements

- `npm run check-version` requires internet access to check GitHub API and RSS feeds
- `npm run update-exiftool` requires internet access to download from exiftool.org
- All other commands work offline

### Package Dependencies

- `mocha` - Test runner (dev dependency)
- `prettier` - Code formatter (dev dependency)
- `extract-zip` - For extracting downloaded ExifTool packages (dev dependency)
- `xml2js` - For parsing RSS feeds during version checking (dev dependency)
- **NO RUNTIME DEPENDENCIES** - this is intentional for security and simplicity

## Common Tasks Reference

### Quick Commands List

```bash
# Install (required --force on non-Windows)
npm install --force

# Test (always run after changes)
npm test

# Format code (always run before committing)
npm run prettier

# Check for ExifTool updates (requires internet)
npm run check-version

# Update ExifTool binary (requires internet)
npm run update-exiftool

# Verify main functionality
node -e "console.log(require('./index.js'))"
```

### Typical Workflow Times

- `npm install --force`: 15-30 seconds
- `npm test`: <1 second
- `npm run prettier`: <1 second
- `npm run check-version`: 5-30 seconds (network dependent)
- `npm run update-exiftool`: 30-120 seconds (download dependent)

## Troubleshooting

### Common Issues

- **Platform error during npm install**: Use `npm install --force` on non-Windows systems
- **Network errors during version check**: Ensure internet access to github.com and exiftool.org
- **Binary not found**: Verify `bin/exiftool.exe` exists and `index.js` exports correct path
- **Test failures**: Usually indicates missing or corrupted binary file

### When to Use Each Command

- Use `npm test` after any code changes to verify basic functionality
- Use `npm run prettier` before every commit to maintain code style
- Use `npm run check-version` to check if updates are available
- Use `npm run update-exiftool` only when you want to update to the latest ExifTool version
