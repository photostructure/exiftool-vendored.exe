# Releasing `exiftool-vendored.exe`

The package's major.minor is the vendored ExifTool version: ExifTool 13.61
ships as `13.61.0`, and a package-only release after it as `13.61.1`.

## Write the release notes

Each release's notes are its section of `CHANGELOG.md`, under an Unreleased
heading that names the release's version.

- For an ExifTool update, `npm run update:exiftool` writes the note. It
  changes the heading to `## [Unreleased (13.61.0)]` and adds
  `- 📦 Updated ExifTool to [13.61](https://exiftool.org/history.html#v13.61).`,
  or replaces that line if an earlier update was never released. Commit
  `CHANGELOG.md` with the updated `bin/` and package metadata. If the
  heading is missing or names minor or major, the update stops before it
  replaces `bin/` and says what to change.
- For a package-only release, write the note by hand: rename
  `## [Unreleased]` to `## [Unreleased (13.61.1)]`, the next patch version,
  and list the changes under it. `## [Unreleased (patch)]` does the same.

The release job fails before it commits anything when the version's
major.minor is not the vendored ExifTool version, as with
`## [Unreleased (major)]`, or `## [Unreleased (minor)]` once that ExifTool's
X.Y.0 is released.

## Release

1. Merge the ExifTool update or other release changes, with their
   `CHANGELOG.md` notes, into `main` and wait for ordinary CI to pass.
2. Open **Build & Prepare Release** in GitHub Actions and run it from `main`.
   It reads the version from the `CHANGELOG.md` heading while the tests run,
   and fails with instructions if the heading is missing, names no version or
   bump, or has no notes under it. Once both pass, it runs `npm version` with
   that version, renames the
   heading to `## [X.Y.Z] - YYYY-MM-DD` with a new empty `## [Unreleased]`
   above it, adds the version's link definition, and pushes the signed release
   commit and tag.
   [`photostructure/changelog-release-action`](https://github.com/photostructure/changelog-release-action)
   does the `CHANGELOG.md` work and the npm wait below.
3. Wait for that workflow, then for the **Stage package on npm** job of the
   tag-bound **Stage npm Release** workflow. Leave that workflow running: its
   **Create immutable GitHub release** job waits for your npm approval.
4. Inspect the package under **Staged Packages** on npmjs.com, including its
   files, metadata, checksum evidence, and provenance.
5. Approve the stage with a maintainer's 2FA key.
6. Wait for the **Create immutable GitHub release** job to finish, then confirm
   that the GitHub release exists, is immutable, and has the version's
   `CHANGELOG.md` section at the top of its notes.

The **Create immutable GitHub release** job checks npm every 5 minutes, for up
to 5 hours 45 minutes, and creates the release once npm serves the approved
version. Its notes are the version's `CHANGELOG.md` section, followed by
GitHub's generated notes. GitHub emails the release to the repository's
watchers at that moment, so the email announces a version they can install.

## Recover from a failed release

- If the staged contents are wrong, reject the stage and release a new version.
  The rejected run's **Create immutable GitHub release** job then runs out of
  checks and fails without creating a release. Cancel that run, or ignore its
  failure, and do not re-run it.
- The release commit of a version that was never published has already moved
  its notes under `## [X.Y.Z] - YYYY-MM-DD` in `CHANGELOG.md`, and the next
  release run fails until `## [Unreleased]` names a version and has notes.
  Rename that empty heading to `## [Unreleased (X.Y.Z+1)]`, the next patch
  version, move the unpublished version's notes under it, leave a line under
  `## [X.Y.Z]` saying that version was never published, and then start the new
  release.
- If the **Create immutable GitHub release** job fails before it creates the
  release (its checks ran out before you approved the stage, or `npm view`
  failed with an error other than E404), approve the stage if you have not,
  then use **Re-run failed jobs** on that **Stage npm Release** run. GitHub
  allows re-runs for 30 days. Do not start a new release.

Do not create or move a version tag manually, run `npm publish`, or approve a
stage whose package identity, contents, provenance, or tag commit is wrong.
