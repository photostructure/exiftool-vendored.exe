// @ts-check

const { readdirSync } = require("node:fs");
const { join } = require("node:path");

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

  return { patchFiles };
}

const { patchFiles } = loadVendorPatchSet(PatchDirectory);

module.exports = { loadVendorPatchSet, patchFiles };
