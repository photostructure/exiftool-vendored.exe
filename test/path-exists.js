const fs = require("node:fs");
const { spawn, spawnSync } = require("node:child_process");
const assert = require("node:assert");
const os = require("node:os");
const nodePath = require("node:path");
const manifest = require("../vendor-manifest.json");
const pkg = require("../package.json");
const { matchesVendorManifest } = require("../lib/vendor-manifest");
const { patchSetSha256 } = require("../lib/vendor-patch-set");
const {
  requiredPackageVersionRepair,
  requireMatchingArchiveVersion,
} = require("../update-exiftool");

async function beforeTimeout(promise, timeoutMs, message) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(message)), timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function spawnStayOpen(exiftoolPath, argFile, options = {}) {
  const child = spawn(
    exiftoolPath,
    ["-stay_open", "True", "-@", argFile],
    options,
  );
  const output = { stdout: "", stderr: "" };
  child.stdout.on("data", (chunk) => {
    output.stdout += chunk.toString();
  });
  child.stderr.on("data", (chunk) => {
    output.stderr += chunk.toString();
  });
  const closed = new Promise((resolve, reject) => {
    child.once("close", (code, signal) => resolve({ code, signal }));
    child.once("error", reject);
  });
  return { child, closed, output };
}

async function waitForStdout(session, expected) {
  await beforeTimeout(
    (async () => {
      while (!session.output.stdout.includes(expected)) {
        if (
          session.child.exitCode != null ||
          session.child.signalCode != null
        ) {
          throw new Error(
            `ExifTool exited before ${JSON.stringify(expected)}: ` +
              JSON.stringify(session.output),
          );
        }
        await delay(10);
      }
    })(),
    3_000,
    `ExifTool did not print ${JSON.stringify(expected)}`,
  );
}

async function cleanupStayOpen(session) {
  if (
    session != null &&
    session.child.exitCode == null &&
    session.child.signalCode == null
  ) {
    session.child.kill("SIGKILL");
    await beforeTimeout(
      session.closed,
      3_000,
      "ExifTool could not be cleaned up",
    );
  }
}

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

    it("exits when stay-open stdin reaches EOF", async function () {
      this.timeout(10_000);
      const path = require("..");
      const session = spawnStayOpen(path, "-");

      try {
        session.child.stdin.write("-ver\n-execute\n");
        await waitForStdout(session, "{ready}");
        session.child.stdin.end();
        const result = await beforeTimeout(
          session.closed,
          2_000,
          "ExifTool stayed alive after stdin EOF",
        );
        assert.deepStrictEqual(
          result,
          { code: 0, signal: null },
          session.output.stderr,
        );
      } finally {
        await cleanupStayOpen(session);
      }
    });

    it("still honors explicit stay-open shutdown", async function () {
      this.timeout(10_000);
      const path = require("..");
      const session = spawnStayOpen(path, "-");

      try {
        session.child.stdin.write("-ver\n-execute\n");
        await waitForStdout(session, "{ready}");
        session.child.stdin.write("-stay_open\nFalse\n");
        const result = await beforeTimeout(
          session.closed,
          2_000,
          "ExifTool ignored explicit stay-open shutdown",
        );
        assert.deepStrictEqual(
          result,
          { code: 0, signal: null },
          session.output.stderr,
        );
      } finally {
        await cleanupStayOpen(session);
      }
    });

    it("keeps polling regular-file stdin after EOF", async function () {
      this.timeout(10_000);
      const exiftoolPath = require("..");
      const tempDir = fs.mkdtempSync(
        nodePath.join(os.tmpdir(), "exiftool-stdin-"),
      );
      const stdinPath = nodePath.join(tempDir, "args.txt");
      fs.writeFileSync(stdinPath, "-ver\n-execute1\n");
      const stdinFd = fs.openSync(stdinPath, "r");
      let session;

      try {
        try {
          session = spawnStayOpen(exiftoolPath, "-", {
            stdio: [stdinFd, "pipe", "pipe"],
          });
        } finally {
          fs.closeSync(stdinFd);
        }
        await waitForStdout(session, "{ready1}");

        const earlyExit = await Promise.race([
          session.closed,
          delay(200).then(() => null),
        ]);
        assert.strictEqual(
          earlyExit,
          null,
          "regular-file stdin must remain open for appended arguments",
        );

        fs.appendFileSync(stdinPath, "-ver\n-execute2\n");
        await waitForStdout(session, "{ready2}");
        fs.appendFileSync(stdinPath, "-stay_open\nFalse\n");
        const result = await beforeTimeout(
          session.closed,
          2_000,
          "ExifTool ignored explicit shutdown from regular-file stdin",
        );
        assert.deepStrictEqual(
          result,
          { code: 0, signal: null },
          session.output.stderr,
        );
      } finally {
        await cleanupStayOpen(session);
        fs.rmSync(tempDir, { recursive: true, force: true });
      }
    });

    it("keeps polling a regular ARGFILE after EOF", async function () {
      this.timeout(10_000);
      const exiftoolPath = require("..");
      const tempDir = fs.mkdtempSync(
        nodePath.join(os.tmpdir(), "exiftool-argfile-"),
      );
      const argFile = nodePath.join(tempDir, "args.txt");
      fs.writeFileSync(argFile, "-ver\n-execute1\n");
      let session;

      try {
        session = spawnStayOpen(exiftoolPath, argFile);
        await waitForStdout(session, "{ready1}");

        const earlyExit = await Promise.race([
          session.closed,
          delay(200).then(() => null),
        ]);
        assert.strictEqual(
          earlyExit,
          null,
          "a regular ARGFILE must remain open for appended arguments",
        );

        fs.appendFileSync(argFile, "-ver\n-execute2\n");
        await waitForStdout(session, "{ready2}");
        fs.appendFileSync(argFile, "-stay_open\nFalse\n");
        const result = await beforeTimeout(
          session.closed,
          2_000,
          "ExifTool ignored explicit shutdown from its ARGFILE",
        );
        assert.deepStrictEqual(
          result,
          { code: 0, signal: null },
          session.output.stderr,
        );
      } finally {
        await cleanupStayOpen(session);
        fs.rmSync(tempDir, { recursive: true, force: true });
      }
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
    assert.strictEqual(manifest.patchSetSha256, patchSetSha256);
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
