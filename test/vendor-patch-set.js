const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { loadVendorPatchSet } = require("../lib/vendor-patch-set");

describe("vendor patch set", () => {
  it("supports missing and empty patch directories", () => {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "vendor-patches-"));

    try {
      assert.deepStrictEqual(
        loadVendorPatchSet(path.join(tempDir, "missing")),
        { patchFiles: [] },
      );

      const emptyDir = path.join(tempDir, "empty");
      fs.mkdirSync(emptyDir);
      assert.deepStrictEqual(loadVendorPatchSet(emptyDir), { patchFiles: [] });
    } finally {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  });
});
