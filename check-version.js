#!/usr/bin/env node
// @ts-check

const { checkForUpdate } = require("./lib/version-utils");

// Set process.exitCode and let the event loop drain rather than calling
// process.exit(): global fetch() hands the TLS socket to an undici worker
// thread, and on Windows process.exit() races that thread's teardown and aborts
// the process with "Assertion failed: !(handle->flags & UV_HANDLE_CLOSING)"
// (nodejs/node#56645). The workflow reads our exit code, so an abort here reads
// as a failed update check.
async function main() {
  try {
    const { currentVersion, latestVersion, updateAvailable } =
      await checkForUpdate();

    console.log(`Current version: ${currentVersion}`);
    console.log(`Latest version:  ${latestVersion}`);

    if (updateAvailable) {
      console.log("📦 Update available");
      process.exitCode = 1;
    } else {
      console.log("✅ Already up to date");
      process.exitCode = 0;
    }
  } catch (error) {
    console.error("❌ Error:", error.message);
    process.exitCode = 2;
  }
}

if (require.main === module) {
  main();
}

module.exports = { checkForUpdate };
