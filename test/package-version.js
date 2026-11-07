const assert = require("node:assert/strict");
const {
  exiftoolMajorMinor,
  packageFollowsExifTool,
  requiredPackageVersionRepair,
} = require("../lib/package-version");

/** @param {string} version */
function lockAt(version) {
  return { version, packages: { "": { version } } };
}

describe("ExifTool versions with a zero-padded minor", () => {
  it("reads ExifTool 14.05 as major 14, minor 5", () => {
    assert.deepEqual(exiftoolMajorMinor("14.05"), [14, 5]);
    assert.deepEqual(exiftoolMajorMinor("14.00"), [14, 0]);
    assert.deepEqual(exiftoolMajorMinor("13.61"), [13, 61]);
  });

  it("matches ExifTool 14.05 with package 14.5.x and nothing else", () => {
    assert.equal(packageFollowsExifTool("14.5.0", "14.05"), true);
    assert.equal(packageFollowsExifTool("14.5.2", "14.05"), true);
    assert.equal(packageFollowsExifTool("14.5.0-pre", "14.05"), true);
    assert.equal(packageFollowsExifTool("14.0.0", "14.00"), true);
    assert.equal(packageFollowsExifTool("14.50.0", "14.05"), false);
    assert.equal(packageFollowsExifTool("14.5.0", "14.50"), false);
    assert.equal(packageFollowsExifTool("13.5.0", "14.05"), false);
  });

  it("leaves package 14.5.0-pre alone for ExifTool 14.05", () => {
    assert.equal(
      requiredPackageVersionRepair("14.5.0-pre", lockAt("14.5.0-pre"), "14.05"),
      null,
    );
  });

  it("repairs an older package version to 14.5.0-pre for ExifTool 14.05", () => {
    assert.equal(
      requiredPackageVersionRepair("13.61.0", lockAt("13.61.0"), "14.05"),
      "14.5.0-pre",
    );
  });
});
