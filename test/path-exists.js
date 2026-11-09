const fs = require("node:fs");
const { spawn, spawnSync } = require("node:child_process");
const assert = require("node:assert");
const os = require("node:os");
const nodePath = require("node:path");
const {
  renameWithRetry,
  requireMatchingArchiveVersion,
} = require("../update-exiftool");
const { exiftoolMajorMinor } = require("../lib/package-version");

// The vendored ExifTool's version as `exiftool -ver` prints it, such as
// "14.05". The package version can't supply it: ExifTool 14.05 ships as
// package 14.5.0.
const exiftoolVersion = /^\$VERSION = '(\d+\.\d+)';$/m.exec(
  fs.readFileSync(
    nodePath.join(
      __dirname,
      "..",
      "bin",
      "exiftool_files",
      "lib",
      "Image",
      "ExifTool.pm",
    ),
    "utf8",
  ),
)?.[1];
if (exiftoolVersion == null) {
  throw new Error("Image/ExifTool.pm has no $VERSION line");
}
const [major, minor] = exiftoolMajorMinor(exiftoolVersion);

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
      assert.strictEqual(result.stdout.toString().trim(), exiftoolVersion);
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

    describe("ImageHashProgress (patches/2026-09-24-exiftool-imagehash-progress.patch)", () => {
      let tempDir;
      let jpeg;

      before(() => {
        tempDir = fs.mkdtempSync(
          nodePath.join(os.tmpdir(), "exiftool-progress-"),
        );
        jpeg = nodePath.join(tempDir, "scan.jpg");
        // SOI, a bare SOS header, 64 runs of 64 KiB scan data, then EOI.
        // ExifTool hashes JPEG scan data one 0xff-delimited run at a time, so
        // stuffed 0xff00 bytes between the runs make each run a separate
        // digest add. (Stuffing right before EOI would add an empty run, which
        // repeats the last count.)
        const scan = [];
        for (let i = 0; i < 64; i++) {
          if (i > 0) scan.push(Buffer.from([0xff, 0x00]));
          scan.push(Buffer.alloc(64 << 10, 0x5a));
        }
        fs.writeFileSync(
          jpeg,
          Buffer.concat([
            Buffer.from([0xff, 0xd8, 0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00]),
            Buffer.from([0x00, 0x3f, 0x00]),
            ...scan,
            Buffer.from([0xff, 0xd9]),
          ]),
        );
      });

      after(() => fs.rmSync(tempDir, { recursive: true, force: true }));

      function hashImageData(...apiArgs) {
        const result = spawnSync(require(".."), [
          ...apiArgs.flatMap((ea) => ["-api", ea]),
          "-ImageDataHash",
          "-s3",
          jpeg,
        ]);
        assert.ifError(result.error);
        assert.strictEqual(result.status, 0, result.stderr.toString());
        return {
          hash: result.stdout.toString().trim(),
          stderr: result.stderr.toString().split(/\r?\n/).filter(Boolean),
        };
      }

      it("reports increasing bytes hashed on stderr", () => {
        const { hash, stderr } = hashImageData("ImageHashProgress=0.000001");
        // Hashing each 64 KiB run takes far longer than the 1 µs interval.
        assert(
          stderr.length >= 64,
          `expected a line per run, got ${stderr.length}`,
        );
        const bytes = stderr.map((line) => {
          const m = /^\{progress:(\d+)\}$/.exec(line);
          assert(m != null, "unexpected stderr line: " + JSON.stringify(line));
          return Number(m[1]);
        });
        for (let i = 1; i < bytes.length; i++) {
          assert(
            bytes[i] > bytes[i - 1],
            "not increasing: " + bytes.join(", "),
          );
        }
        assert(bytes.at(-1) <= fs.statSync(jpeg).size);
        assert.strictEqual(hash, hashImageData().hash);
      });

      it("prints nothing unless requested", () => {
        const { hash, stderr } = hashImageData();
        assert.match(hash, /^[0-9a-f]{32}$/);
        assert.deepStrictEqual(stderr, []);
      });
    });
  }
});

describe("update-exiftool.js", () => {
  it("rejects a download whose archive and latest tag disagree", () => {
    // Ground truth: curl -fsSL https://exiftool.org/rss.xml | grep -F
    // "exiftool-13.59_64.zip" shows the official x64 archive naming scheme.
    const filename = `exiftool-${exiftoolVersion}_64.zip`;
    assert.strictEqual(
      requireMatchingArchiveVersion(filename, exiftoolVersion),
      exiftoolVersion,
    );
    assert.throws(
      () => requireMatchingArchiveVersion(filename, `${major}.${minor + 1}`),
      /does not match archive/,
    );
    assert.throws(
      () =>
        requireMatchingArchiveVersion(
          `exiftool-${exiftoolVersion}_32.zip`,
          exiftoolVersion,
        ),
      /does not match archive/,
    );
  });

  describe("renameWithRetry", () => {
    function renameFailing(failures, code) {
      const calls = { renames: 0, delays: [] };
      const impl = {
        renameImpl: async () => {
          calls.renames++;
          if (calls.renames <= failures) {
            throw Object.assign(new Error("rename failed"), { code });
          }
        },
        delayImpl: async (ms) => {
          calls.delays.push(ms);
        },
      };
      return { calls, impl };
    }

    it("retries EPERM until the rename succeeds", async () => {
      const { calls, impl } = renameFailing(2, "EPERM");
      await renameWithRetry("from", "to", impl);
      assert.strictEqual(calls.renames, 3);
      assert.deepStrictEqual(calls.delays, [1000, 1000]);
    });

    it("rejects with EPERM after five retries", async () => {
      const { calls, impl } = renameFailing(Infinity, "EPERM");
      await assert.rejects(renameWithRetry("from", "to", impl), {
        code: "EPERM",
      });
      assert.strictEqual(calls.renames, 6);
    });

    it("does not retry other errors", async () => {
      const { calls, impl } = renameFailing(Infinity, "ENOENT");
      await assert.rejects(renameWithRetry("from", "to", impl), {
        code: "ENOENT",
      });
      assert.strictEqual(calls.renames, 1);
      assert.deepStrictEqual(calls.delays, []);
    });
  });
});
