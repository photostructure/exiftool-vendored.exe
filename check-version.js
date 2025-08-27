#!/usr/bin/env node
// @ts-check

const { checkForUpdate } = require("./lib/version-utils");

async function main() {
  try {
    const { currentVersion, latestVersion, updateAvailable } =
      await checkForUpdate();

    console.log(`Current version: ${currentVersion}`);
    console.log(`Latest version:  ${latestVersion}`);

    if (updateAvailable) {
      console.log("📦 Update available");
      process.exit(1);
    } else {
      console.log("✅ Already up to date");
      process.exit(0);
    }
  } catch (error) {
    console.error("❌ Error:", error.message);
    process.exit(2);
  }
}

if (require.main === module) {
  main();
}

module.exports = { checkForUpdate };
