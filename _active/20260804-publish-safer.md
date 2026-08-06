---
title: Safer npm publishing
kind: TPP
status: active
governing_spec: ../../PUBLISH-SAFER.md
---

# TPP: safer npm publishing

## Summary

Migrate `exiftool-vendored.exe` from a combined direct-publish release job to a
tested, signed tag followed by isolated npm staged publishing and human 2FA
approval. The governing requirements are `/home/mrm/src/PUBLISH-SAFER.md`.

## Current phase

Next: merge the migration, confirm ordinary CI, and run the Phase 3 patch-release
drill. Delete legacy remote branches only after explicit maintainer approval.

- [x] Phase 0 inventory
- [x] Manual npm and GitHub settings gate — maintainer confirmed 2026-08-04
- [x] Phase 1 repository changes
- [x] Phase 2 local and static verification
- [ ] Phase 3 patch-release drill
- [ ] Phase 4 cleanup and rollout

## Required reading

- `CLAUDE.md`
- `/home/mrm/src/PUBLISH-SAFER.md`
- `/home/mrm/src/mkver/.github/workflows/{build.yml,publish.yaml,check-workflows.yaml}`
- `.github/workflows/{build.yml,check-updates.yml}`
- `package.json`, `update-exiftool.js`, and `test/path-exists.js`

## Project record

- Public GitHub repository: `photostructure/exiftool-vendored.exe`, default
  branch `main`; package metadata and origin identify the same repository.
- Public npm package: `exiftool-vendored.exe`; current stable release and sole
  dist-tag are `13.59.0` and `latest`.
- Existing release tags are bare versions such as `13.59.0`; preserve that
  syntax.
- npm-managed single-package repository with lockfile v3 and no private
  registry dependencies.
- Release test gate: Node.js 22, 24, and 26 on `windows-latest` (x64).
- Vendored payload: the official Windows x64 ExifTool distribution. The updater
  already verifies the published SHA-256 and size; add a checked-in manifest
  recording version, URL, platform, architecture, filename, and checksum.
- `release-it` supplies the signed version commit, signed annotated tag, GitHub
  release notes, and direct npm publication. Preserve the first three and
  replace the last with staged publishing.
- Classic `main` protection requires signed commits and permits the current
  signed direct push. No repository ruleset was returned; organization
  rulesets could not be inspected with the available token.
- Repository and the `copilot` environment Actions secret inventories contain
  no npm token. The maintainer confirmed that organization settings and token
  access satisfy the manual gate.
- Releases are immutable and organization 2FA is required. Before the gate,
  Actions defaults were writable and fork approval covered only first-time
  contributors; the maintainer confirmed the required settings changes.
- `npm pack --dry-run --ignore-scripts --json` defines the accepted boundary:
  `LICENSE`, `README.md`, `index.js`, `package.json`, and `bin/**` only.

## Decisions

- Keep manual patch/minor/major dispatch, bare version tags, stable-only
  releases, and the npm `latest` dist-tag.
- Use a 14-day dependency and Action cooldown with no exclusions.
- Use the repository `GITHUB_TOKEN` pilot for the signed atomic version/tag
  push and explicit tag-bound publisher dispatch.
- Create the immutable GitHub release after npm accepts the stage; the human
  2FA approval remains the final npm publication gate.
- Use no npm publishing token, no project dependency, no checkout, and no cache
  in the OIDC staging job.

## Tasks and acceptance

- [x] Replace `release-it` and the legacy release job with `build.yml` and
      `publish.yaml`; acceptance: `actionlint`, pinact, and both zizmor personas.
- [x] Add npm, npm-check-updates, and pinact 14-day controls; acceptance:
      frozen install plus `git diff --exit-code` after lockfile regeneration.
- [x] Record the verified upstream artifact identity in a checked-in manifest;
      acceptance: the updater rejects a checksum mismatch before extraction.
- [x] Test the executable from the packed tarball on Windows x64; acceptance:
      the tag-bound workflow runs the extracted package executable.
- [x] Verify package, test, audit, and tarball boundary commands from the
      governing specification.

## Handoff log

### 2026-08-04 — inventory and settings gate complete

- Current phase: Phase 1 implementation.
- Completed: local/GitHub/npm inventory, package-boundary dry run, release
  behavior mapping, and maintainer settings confirmation.
- Evidence: `npm view`, `npm pack --dry-run --ignore-scripts --json`, GitHub
  settings APIs, tag/signature inspection, and all-workflow searches completed.
- Deliberate exception: repository `GITHUB_TOKEN` remains the temporary release
  identity until an organization GitHub App and tag-ruleset bypass exist.
- Working-tree state: clean before this TPP was created.
- Exact next action: implement Phase 1.
- Blockers requiring maintainer action: none until the patch-release drill.

### 2026-08-04 — implementation and static verification complete

- Current phase: Phase 3 patch-release drill after merge and green ordinary CI.
- Completed: removed `release-it`; added the signed atomic release flow,
  tag-bound staged publisher, least-privilege workflow audit, 14-day npm/ncu/
  pinact controls, immutable package evidence, checked-in upstream manifest,
  packed-executable Windows smoke test, and maintainer release procedure.
- Verification exited successfully: frozen install with scripts disabled,
  Prettier lint, Mocha manifest tests, updater no-op, actual `npm pack`
  checksum/identity/content checks, `actionlint`, pinact v4.1.0
  `run --check --verify`, the pinact cooldown update/diff, and regular-persona
  zizmor. Executing the packed `.exe` remains an intentional Windows
  CI/platform check.
- `npm audit --omit=dev` exited zero. Full `npm audit` reports four
  development-only paths through Mocha: `diff` (low), Mocha aggregation
  (moderate), `brace-expansion` and `serialize-javascript` (high). The fixed
  `brace-expansion` releases are younger than the approved 14-day gate; Mocha's
  compatible dependency ranges have no fixed `diff` or `serialize-javascript`.
  These tools consume only repository-controlled tests outside the OIDC job;
  packing installs no dependencies and the published package has none.
- Auditor-persona zizmor records six deliberate findings: the release job's
  required credential-persisting checkout; the intentionally absent
  workflow-wide concurrency on combined CI/manual release; three organization
  signing secrets outside a dedicated environment; and the pinned
  `create-pull-request` Action retained for signed automated update commits.
  The release job has only `contents: write`, runs only after the full matrix,
  rechecks the remote default-branch SHA, installs no project dependencies, and
  has no npm OIDC authority. The update job runs only from trusted scheduled or
  manual default-branch source and has only contents/PR authority.
- GitHub Actions does not currently accept the specification's `queue: single`
  key (`actionlint` rejects it). Native concurrency still permits one running
  and one pending release per group; `cancel-in-progress: false` is retained.
- Self-review accepted four findings: tarball discovery now uses portable Bash
  arrays; the release job rejects a package version whose major/minor pair
  disagrees with the vendored manifest before creating a tag; the updater
  rejects disagreement between the latest tag, RSS archive name, and extracted
  executable before writing the manifest; and the helper now installs
  cooldown-eligible pinact v4.1.0 instead of v3. The archive mismatch has a
  regression test pinned to the official RSS naming. Auditor suggestions to
  remove release credentials, add workflow-wide concurrency, move the signing
  secrets, or replace signed PR automation were vetoed because they conflict
  with the governing flow and the compensating controls recorded above.
- The cross-model second-opinion command ended with an execution error, so the
  documented same-model fallback performed a read-only review. It found that
  the updater's old version-only no-op could trust a stale or falsified
  manifest. The updater now fetches authoritative RSS/checksum metadata before
  a no-op, requires every manifest field and the executable version to match,
  and has a regression test for a well-formed incorrect checksum. The live
  authenticated no-op passed after this fix. This fallback is useful but
  provides less model diversity than the intended cross-model review.
- The fallback also questioned keeping patch/minor/major release choices. That
  suggestion was vetoed: the maintainer explicitly approved the existing
  interface, local npm 11.16.0 version drills confirmed how each choice maps
  from stable and `-pre` package versions, and the pre-tag manifest guard
  rejects a stable version whose major/minor pair cannot describe the vendored
  ExifTool release.
- The checked-in Windows payload was compared with the official x64 archive
  whose SHA-256 is
  `44b512b25af500724ba579d0a53c8fc5851628b692dd5e5d94ae4a15c2cba9ec`.
  The trees match exactly after the repository's documented CRLF-to-LF text
  normalization and the updater's `exiftool(-k).exe` rename.
- Staged-review fixes made the local gates self-enforcing: every dependency
  update path rejects npm older than 11.10 before resolution, Action updates
  execute exact pinact v4.1.0 so the configured cooldown cannot be silently
  ignored, and an interrupted updater repairs stale package/lockfile versions
  on retry instead of treating the partial result as complete.
- The post-gate branch scan found legacy release workflows on
  `claude/review-exiftool-pr-77-qdoZD`, `copilot/fix-31`,
  `copilot/fix-bf8ac096-e66a-42b2-99e5-952e311cbda1`, and
  `update-exiftool-13.29.0`, `13.30.0`, `13.31.0`, `13.33.0`, and `13.34.0`.
  These remote branches must be deleted or locked after maintainer approval.
- Working-tree state: migration changes are intentionally uncommitted; no
  pre-existing user changes were present.
- Exact next action: review and merge this migration, wait for ordinary CI,
  then follow `RELEASING.md` for the patch-release drill.
- Blockers requiring maintainer action: approve the staged package with 2FA and
  approve deletion of the listed stale remote branches.
