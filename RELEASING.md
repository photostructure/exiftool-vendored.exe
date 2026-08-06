# Releasing `exiftool-vendored.exe`

1. Merge the ExifTool update or other release changes into `main` and wait for
   ordinary CI to pass.
2. Open **Build & Prepare Release** in GitHub Actions, run it from `main`, and
   choose `patch`, `minor`, or `major` from the consumer-visible change.
3. Wait for that workflow and the tag-bound **Stage npm Release** workflow.
4. Inspect the package under **Staged Packages** on npmjs.com, including its
   files, metadata, checksum evidence, and provenance.
5. Approve the stage with a maintainer's 2FA key.

Do not create or move a version tag manually, run `npm publish`, or approve a
stage whose package identity, contents, provenance, or tag commit is wrong.
