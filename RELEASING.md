# Releasing `exiftool-vendored.exe`

1. Merge the ExifTool update or other release changes into `main` and wait for
   ordinary CI to pass.
2. Open **Build & Prepare Release** in GitHub Actions and run it from `main`.
   The package's major.minor is the vendored ExifTool version, so the workflow
   always bumps patch: an ExifTool update's `13.60.0-pre` becomes `13.60.0`,
   and a package-only release's `13.59.2` becomes `13.59.3`.
3. Wait for that workflow, then for the **Stage package on npm** job of the
   tag-bound **Stage npm Release** workflow. Leave that workflow running: its
   **Create immutable GitHub release** job waits for your npm approval.
4. Inspect the package under **Staged Packages** on npmjs.com, including its
   files, metadata, checksum evidence, and provenance.
5. Approve the stage with a maintainer's 2FA key.
6. Wait for the **Create immutable GitHub release** job to finish, then confirm
   that the GitHub release exists and is immutable.

The **Create immutable GitHub release** job checks npm every 5 minutes, for up
to 5 hours 45 minutes, and creates the release (with generated notes) once npm
serves the approved version. GitHub emails the release to the repository's
watchers at that moment, so the email announces a version they can install. If
the job fails before it creates the release (its checks ran out before you
approved the stage, or `npm view` failed with an error other than E404), approve
the stage if you have not, then use **Re-run failed jobs** on that **Stage npm
Release** run. GitHub allows re-runs for 30 days. Do not start a new release.

If the staged contents are wrong, reject the stage and release a new version.
The rejected run's **Create immutable GitHub release** job then runs out of
checks and fails without creating a release. Cancel that run, or ignore its
failure, and do not re-run it.

Do not create or move a version tag manually, run `npm publish`, or approve a
stage whose package identity, contents, provenance, or tag commit is wrong.
