// @ts-check

const { createHash } = require("node:crypto");
const { readFileSync, readdirSync } = require("node:fs");
const { basename, join } = require("node:path");

const PatchDirectory = join(__dirname, "..", "patches");

/**
 * @param {string} patchDirectory
 */
function loadVendorPatchSet(patchDirectory) {
  let patchNames;
  try {
    patchNames = readdirSync(patchDirectory);
  } catch (error) {
    const err = /** @type {{ code?: string }} */ (error);
    if (err?.code === "ENOENT") patchNames = [];
    else throw error;
  }

  const patchFiles = patchNames
    .filter((name) => name.endsWith(".patch"))
    .sort()
    .map((name) => join(patchDirectory, name));

  const patchSetHash = createHash("sha256");
  for (const patchFile of patchFiles) {
    patchSetHash
      .update(basename(patchFile))
      .update("\0")
      .update(readFileSync(patchFile))
      .update("\0");
  }
  return { patchFiles, patchSetSha256: patchSetHash.digest("hex") };
}

const { patchFiles, patchSetSha256 } = loadVendorPatchSet(PatchDirectory);

module.exports = { loadVendorPatchSet, patchFiles, patchSetSha256 };
