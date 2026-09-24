# Releasing `exiftool-vendored.exe`

1. Merge the ExifTool update or other release changes into `main` and wait for
   ordinary CI to pass.
2. Open **Build & Prepare Release** in GitHub Actions and run it from `main`.
   The package's major.minor is the vendored ExifTool version, so the workflow
   always bumps patch: an ExifTool update's `13.60.0-pre` becomes `13.60.0`,
   and a package-only release's `13.59.2` becomes `13.59.3`.
3. Wait for that workflow and the tag-bound **Stage npm Release** workflow.
4. Inspect the package under **Staged Packages** on npmjs.com, including its
   files, metadata, checksum evidence, and provenance.
5. Approve the stage with a maintainer's 2FA key.

Do not create or move a version tag manually, run `npm publish`, or approve a
stage whose package identity, contents, provenance, or tag commit is wrong.
