const fs = require("fs");
const { spawnSync } = require("node:child_process");
const assert = require("assert");
const manifest = require("../vendor-manifest.json");
const pkg = require("../package.json");
const { matchesVendorManifest } = require("../lib/vendor-manifest");
const {
  requiredPackageVersionRepair,
  requireMatchingArchiveVersion,
} = require("../update-exiftool");

describe("exported path", () => {
  it("is a valid path to a file", () => {
    const path = require("..");
    assert(fs.existsSync(path));
  });

  if (process.platform === "win32") {
    it("runs the vendored executable", () => {
      const path = require("..");
      const result = spawnSync(path, ["-ver"]);

      assert.ifError(result.error);
      assert.strictEqual(result.status, 0);
      assert.strictEqual(result.stdout.toString().trim(), manifest.version);
      assert.strictEqual(result.stderr.toString(), "");
    });
  }
});

describe("vendor manifest", () => {
  it("matches the package and records a verified x64 archive", () => {
    const [major, minor] = pkg.version.replace(/-pre$/, "").split(".");

    assert.strictEqual(manifest.version, `${major}.${minor}`);
    assert.strictEqual(manifest.platform, "win32");
    assert.strictEqual(manifest.architecture, "x64");
    assert.strictEqual(
      manifest.filename,
      `exiftool-${manifest.version}_64.zip`,
    );
    assert(manifest.sourceUrl.includes(manifest.filename));
    assert(Number.isSafeInteger(manifest.size) && manifest.size > 0);
    assert(/^[0-9a-f]{64}$/.test(manifest.sha256));
  });

  it("rejects a download whose archive and latest tag disagree", () => {
    // Ground truth: curl -fsSL https://exiftool.org/rss.xml | grep -F
    // "exiftool-13.59_64.zip" shows the official x64 archive naming scheme.
    assert.strictEqual(
      requireMatchingArchiveVersion(manifest.filename, manifest.version),
      manifest.version,
    );
    assert.throws(
      () => requireMatchingArchiveVersion(manifest.filename, "13.60"),
      /does not match archive/,
    );
    assert.throws(
      () =>
        requireMatchingArchiveVersion(
          `exiftool-${manifest.version}_32.zip`,
          manifest.version,
        ),
      /does not match archive/,
    );
  });

  it("rejects a well-formed but incorrect checksum", () => {
    // Ground truth: https://exiftool.org/checksums.txt publishes the checksum
    // that update-exiftool.js must match before treating an update as a no-op.
    const incorrect = { ...manifest, sha256: "0".repeat(64) };

    assert(matchesVendorManifest(manifest, { ...manifest }));
    assert(!matchesVendorManifest(incorrect, { ...manifest }));
  });

  it("repairs package metadata left stale by an interrupted update", () => {
    const currentLock = {
      version: pkg.version,
      packages: { "": { version: pkg.version } },
    };
    assert.strictEqual(
      requiredPackageVersionRepair(pkg.version, currentLock, manifest.version),
      null,
    );
    assert.strictEqual(
      requiredPackageVersionRepair("13.58.0", currentLock, manifest.version),
      `${manifest.version}.0-pre`,
    );
    assert.strictEqual(
      requiredPackageVersionRepair(
        pkg.version,
        { ...currentLock, version: "13.58.0" },
        manifest.version,
      ),
      pkg.version,
    );
  });
});
