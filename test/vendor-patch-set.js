const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { loadVendorPatchSet } = require("../lib/vendor-patch-set");

const EmptySha256 =
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

describe("vendor patch set", () => {
  it("supports missing and empty patch directories", () => {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "vendor-patches-"));

    try {
      assert.deepStrictEqual(
        loadVendorPatchSet(path.join(tempDir, "missing")),
        {
          patchFiles: [],
          patchSetSha256: EmptySha256,
        },
      );

      const emptyDir = path.join(tempDir, "empty");
      fs.mkdirSync(emptyDir);
      assert.deepStrictEqual(loadVendorPatchSet(emptyDir), {
        patchFiles: [],
        patchSetSha256: EmptySha256,
      });
    } finally {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  });
});
