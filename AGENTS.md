## Project Overview

This is `exiftool-vendored.exe`, a Node.js module that provides the Windows distribution of ExifTool. It's a thin wrapper around the official Windows ExifTool installation (which includes a portable Perl launcher and Strawberry Perl).

The main entry point is `index.js`, which simply exports the path to the vendored exiftool.exe binary located in `bin/exiftool.exe`.

## Common Commands

```bash
# Everything that should pass before a release
make preflight  # or: npm run preflight

# Run tests
npm test

# Format code
npm run prettier

# Update the vendored ExifTool binary to latest version
npm run update:exiftool  # Runs update-exiftool.js to download and install latest ExifTool

# Release procedure
# See RELEASING.md
```

## Architecture

- `index.js` - Main entry point that exports the path to the vendored ExifTool binary
- `update-exiftool.js` - Script that fetches the latest Windows ExifTool package from exiftool.org
  - Downloads the official Windows 64-bit zip package
  - Verifies SHA256 checksums
  - Extracts the verified package into a staging directory
  - Applies every `patches/*.patch` file in lexical filename order with zero fuzz;
    filenames are `YYYY-MM-DD-description.patch`, dated when the patch was written
  - Replaces `bin/` only after every patch applies successfully
  - Writes the release note for a new ExifTool version into `CHANGELOG.md`
- `lib/vendor-patch-set.js` - Discovers the ordered patch series
- `lib/package-version.js` - Compares the package version with the vendored
  ExifTool version as numbers, for the updater and the release workflow
- `lib/changelog.js` - Writes the updater's `CHANGELOG.md` note under
  `## [Unreleased (X.YY.0)]`
- `patches/` - Downstream changes; may be absent when none are required
- `test/path-exists.js` - Tests the executable, stay-open behavior, `ImageHashProgress`, and the updater's version checks
- `verification.sh` - Script to verify the integrity of Oliver Betz's ExifTool package

## Development Workflow

This module follows the ExifTool versioning with an additional patch number when needed:

### Update Detection

1. **Check**: `npm run check-version` exits 1 when a newer ExifTool is available. Nothing runs it on a schedule

2. **Manual Update Process**:
   - Run `npm run update:exiftool` to fetch and install the latest ExifTool binary
   - Run the update from Git Bash, included with Git for Windows, so GNU `bash` and `patch` are available
   - The script applies every `patches/*.patch` file with zero fuzz and stops before replacing `bin/` if any patch fails
   - The script changes the Unreleased heading in `CHANGELOG.md` to `## [Unreleased (13.26.0)]` and adds `- 📦 Updated ExifTool to [13.26](https://exiftool.org/history.html#v13.26).`, replacing the line an earlier unreleased update wrote. It stops before replacing `bin/` if that heading is missing or names minor or major
   - Commit the updated binary, patch series, and `CHANGELOG.md`

If strict patch application fails, do not add fuzz or bypass the patch. Compare
the patch with the new upstream source. Refresh the patch if the downstream
behavior is still required, or remove it if upstream provides equivalent
behavior. Then rerun the update and the full test suite before committing the
patch and `bin/` changes together. If no downstream patches remain, `patches/`
may be absent; the updater then installs the verified upstream package
unchanged.

### Release Process

1. Review and commit the locally generated update, or, for a package-only
   release, write its note by hand in `CHANGELOG.md` under
   `## [Unreleased (13.26.1)]`, the next patch version
2. Go to the Actions tab on GitHub
3. Follow `RELEASING.md`
   - The workflow reads the version from the `CHANGELOG.md` heading and
     refuses one whose major.minor, compared as numbers, is not the vendored
     ExifTool version
   - The full test gate runs before the signed release commit and tag
   - The workflow sets that version and stamps the `CHANGELOG.md` section
     with the version and date
   - The exact tag is packed and staged on npm
   - A maintainer inspects and approves the stage with 2FA
   - Once npm serves the version, the GitHub release is created with that
     `CHANGELOG.md` section as its notes

### Version Numbering

- Versions match ExifTool's version with a patch number: `MAJOR.MINOR.PATCH`
- `package.json` keeps the last released version until the release workflow
  sets the version the `CHANGELOG.md` heading names; SemVer drops a zero-padded
  minor, so ExifTool 14.05 ships as 14.5.0
- Additional patch releases can be made if needed (e.g., "13.26.1" for fixes)
- Minor and major releases are not possible: the version's major.minor is
  always the vendored ExifTool version

## Important Notes

- This package is Windows-only (as declared in package.json `os` field)
- Do not modify files in the `bin/` directory manually - use `update-exiftool.js`
- The base ExifTool binary and associated files are downloaded from official sources; `patches/` records every downstream source change
- This module is used by the main `exiftool-vendored` package for Windows support
- Publishing uses npm Trusted Publishing and must not have an npm publishing
  token. The isolated release job uses `SSH_SIGNING_KEY`, `GIT_USER_NAME`, and
  `GIT_USER_EMAIL` for the signed commit and tag.
- Tests must pass before any release
