#!/usr/bin/env node
// @ts-check

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");

/**
 * npm refuses to install a project whose own package.json `os` field excludes
 * the current platform, and `--os` does not override that check for the root
 * package. `--force` is the only bypass, so use it only off Windows, where the
 * root package's `"os": ["win32"]` would otherwise fail with EBADPLATFORM.
 *
 * @param {NodeJS.Platform} platform
 */
function npmInstallArgs(platform = process.platform) {
  return platform === "win32" ? ["install"] : ["install", "--force"];
}

if (require.main === module) {
  const npmCli = process.env.npm_execpath;
  assert(npmCli, "run this script through an npm script");
  const result = spawnSync(process.execPath, [npmCli, ...npmInstallArgs()], {
    stdio: "inherit",
  });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
}

module.exports = { npmInstallArgs };
