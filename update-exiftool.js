#!/usr/bin/env node
// @ts-check

const { execFileSync, spawnSync } = require("node:child_process");
const { createHash } = require("node:crypto");
const {
  createWriteStream,
  createReadStream,
  readFileSync,
} = require("node:fs");
const {
  mkdir,
  readFile,
  rm,
  rename,
  stat,
  writeFile,
} = require("node:fs/promises");
const { join } = require("node:path");
const { pipeline } = require("node:stream/promises");
const { setTimeout: delay } = require("node:timers/promises");

const xml2js = require("xml2js");
const { unzip } = require("cross-zip");
const {
  fetchWithRetry,
  getLatestExifToolVersion,
} = require("./lib/version-utils");
const { patchFiles } = require("./lib/vendor-patch-set");
const { noteExifToolUpdate } = require("./lib/changelog");

// Currently is "12.88", but "13.1" is valid.

const VersionRE = /\b([\d\.]{4,})\b/;

/**
 * @param {import("node:fs").PathOrFileDescriptor} patchFile
 * @param {string} targetDirectory
 */
function applyVendorPatch(patchFile, targetDirectory) {
  const patchArgs = ["-f", "-F", "0", "-p1"];
  const command = process.platform === "win32" ? "bash" : "patch";
  const args =
    process.platform === "win32"
      ? ["-lc", 'patch "$@"', "patch", ...patchArgs]
      : patchArgs;
  const result = spawnSync(command, args, {
    cwd: targetDirectory,
    encoding: "utf8",
    input: readFileSync(patchFile),
  });
  if (result.error) {
    throw new Error("Could not run vendor patch: " + result.error.message);
  }
  if (result.status !== 0) {
    throw new Error(
      `Applying ${patchFile} failed:\n` + result.stdout + result.stderr,
    );
  }
}

async function fetchLatestEnclosure() {
  const response = await fetchWithRetry("https://exiftool.org/rss.xml");
  const xmlData = await response.text();
  const parser = new xml2js.Parser();
  const xmlDoc = await parser.parseStringPromise(xmlData);
  const items = xmlDoc.rss.channel[0].item;
  let enc;
  for (const item of items) {
    const title = item.title[0];
    const version = /\b(\d{2}\.\d+\b)/.exec(title)?.[1];
    enc = item.enclosure?.find(
      (/** @type {{ $: { type: string; url: string; }; }} */ ea) =>
        ea.$.type === "application/zip" && /_64.zip(?:$|\/)/.test(ea.$.url),
    )?.$;
    if (enc != null) break;
  }
  if (enc == null) {
    throw new Error("No enclosure with a valid download link was found");
  }
  return enc;
}

/**
 * @param {string} basename
 */
async function fetchLatestSHA256(basename) {
  const response = await fetchWithRetry("https://exiftool.org/checksums.txt");
  const text = await response.text();
  for (const line of text.split("\n")) {
    if (line.startsWith("SHA2-256") && line.includes(basename)) {
      const sha256 = /\b([0-9a-f]{64})\b/.exec(line)?.[1];
      if (sha256 != null) return sha256;
      else
        throw new Error("No SHA256 hash was found for matching line: " + line);
    }
  }
  throw new Error("No SHA256 hash was found for basename: " + basename);
}

/**
 * @param {import("fs").PathLike} path
 */
function computeSHA256(path) {
  return new Promise((resolve, reject) => {
    const hash = createHash("sha256");
    const stream = createReadStream(path);

    stream.on("data", (data) => {
      hash.update(data);
    });

    stream.on("end", () => {
      const sha256 = hash.digest("hex");
      resolve(sha256);
    });

    stream.on("error", (error) => {
      reject(error);
    });
  });
}

/**
 * @param {string} basename
 * @param {string} latestVersion
 */
function requireMatchingArchiveVersion(basename, latestVersion) {
  const archiveVersion = /^exiftool-(\d+\.\d+)_64\.zip$/.exec(basename)?.[1];
  if (archiveVersion == null || archiveVersion !== latestVersion) {
    throw new Error(
      `Latest tag ${latestVersion} does not match archive ${basename}`,
    );
  }
  return archiveVersion;
}

const RENAME_MAX_RETRIES = 5;
const RENAME_RETRY_DELAY_MS = 1000;

/**
 * Windows answers EPERM when a directory is renamed while a file inside it is
 * held open. On a Windows 11 checkout, 12 of 15 renames made right after
 * extraction and patching got EPERM on the first attempt, and each succeeded
 * within 106 ms of retrying. What held the tree was not identified. This makes
 * as many retries as the rm() calls in run(), at a fixed delay: 5 s in total.
 *
 * @param {string} from
 * @param {string} to
 * @param {{ renameImpl?: typeof rename, delayImpl?: (ms: number) => Promise<unknown> }} [impl]
 */
async function renameWithRetry(
  from,
  to,
  { renameImpl = rename, delayImpl = delay } = {},
) {
  for (let retries = 0; ; retries++) {
    try {
      return await renameImpl(from, to);
    } catch (e) {
      const { code } = /** @type {NodeJS.ErrnoException} */ (e);
      if (code !== "EPERM" || retries === RENAME_MAX_RETRIES) throw e;
      await delayImpl(RENAME_RETRY_DELAY_MS);
    }
  }
}

/**
 * @param {string | URL | Request} url
 * @param {string} basename
 * @param {string} dir
 * @param {string} sha256
 */
async function wget(url, basename, dir, sha256) {
  await mkdir(dir, { recursive: true });
  const out = join(dir, basename);
  try {
    const s = await stat(out);
    if (s.isFile() && (await computeSHA256(out)) === sha256) {
      console.log("Already downloaded: " + out);
      return out;
    }
  } catch (e) {
    const err = /** @type {any} */ (e);
    if (err && err.code === "ENOENT") {
      // file doesn't exist — that's fine
    } else {
      if (err instanceof Error) throw err;
      throw new Error(String(err));
    }
  }
  await rm(out, { force: true });
  console.log("Fetching ", { url, out });
  const response = await fetchWithRetry(url);
  if (response.body == null) {
    throw new Error("Response body from fetch(" + url + ") is null");
  }
  await pipeline(response.body, createWriteStream(out));
  const actualSha256 = await computeSHA256(out);
  console.log("SHA256:", { expected: sha256, actual: actualSha256 });
  if (actualSha256 !== sha256) {
    throw new Error("SHA256 hash mismatch");
  }

  return out;
}

async function run() {
  const latestVersion = await getLatestExifToolVersion();
  console.log(`Latest version: ${latestVersion}`);

  const enc = await fetchLatestEnclosure();
  const u = new URL(enc.url);
  const pathSegments = u.pathname.split("/").filter((s) => s.length > 0);
  const basename = pathSegments.find((s) => s.endsWith(".zip"));
  if (basename == null) {
    throw new Error("Invalid basename from URL: " + enc.url);
  }
  const archiveVersion = requireMatchingArchiveVersion(basename, latestVersion);
  const expectedSha256 = await fetchLatestSHA256(basename);
  const expectedFileSize = Number.parseInt(enc.length, 10);
  if (!Number.isSafeInteger(expectedFileSize) || expectedFileSize <= 0) {
    throw new Error("Invalid file size from enclosure: " + enc.length);
  }
  const packageJson = JSON.parse(
    await readFile(join(__dirname, "package.json"), "utf8"),
  );
  // Build the CHANGELOG.md note now, so a heading the release would refuse
  // stops the update before it replaces bin/.
  const changelogPath = join(__dirname, "CHANGELOG.md");
  const changelog = await readFile(changelogPath, "utf8");
  const notedChangelog = noteExifToolUpdate(
    changelog,
    packageJson.version,
    archiveVersion,
  );

  const dir = join(__dirname, ".dl");
  const zipPath = await wget(enc.url, basename, dir, expectedSha256);
  const actualFileSize = (await stat(zipPath)).size;
  if (actualFileSize !== expectedFileSize) {
    throw new Error(
      "Unexpected file size: " +
        JSON.stringify({
          actualFileSize,
          expectedFileSize,
          url: enc.url,
          file: zipPath,
        }),
    );
  }

  const expectedZipOutDir = join(dir, basename.replace(/\.zip$/, ""));
  await rm(expectedZipOutDir, {
    recursive: true,
    force: true,
    maxRetries: 5,
    retryDelay: 1000,
  });

  // Extract zip file using cross-zip (uses unzip on Unix, 7zip on Windows)
  await new Promise((resolve, reject) => {
    unzip(zipPath, dir, (err) => {
      if (err) reject(new Error("Failed to extract zip: " + err.message));
      else resolve(undefined);
    });
  });
  // The zip stores every entry as r-x and unzip keeps those modes: patch could
  // not create its temporary files in exiftool_files/, and git would record
  // every file as executable. Windows-built commits store them as 644.
  if (process.platform !== "win32") {
    execFileSync("chmod", ["-R", "u+w,a-x,a+X", expectedZipOutDir]);
  }
  for (const patchFile of patchFiles) {
    applyVendorPatch(patchFile, expectedZipOutDir);
  }

  const destDir = join(__dirname, "bin");
  await rm(destDir, {
    recursive: true,
    force: true,
    maxRetries: 5,
    retryDelay: 1000,
  });
  await renameWithRetry(expectedZipOutDir, destDir);
  await rename(
    join(__dirname, "bin", "exiftool(-k).exe"),
    join(__dirname, "bin", "exiftool.exe"),
  );
  let version;
  if (process.platform === "win32") {
    const versionResult = spawnSync(join(__dirname, "bin", "exiftool.exe"), [
      "-ver",
    ]);
    if (versionResult.error) {
      throw new Error(
        "Failed to get ExifTool version: " + versionResult.error.message,
      );
    }
    if (versionResult.status !== 0) {
      throw new Error(
        "ExifTool version check failed: " +
          versionResult.stderr.toString().trim(),
      );
    }
    version = versionResult.stdout.toString().trim();
  } else {
    version = archiveVersion;
  }
  if (version !== archiveVersion) {
    throw new Error(
      `Archive ${basename} contains ExifTool ${version || "unknown"}`,
    );
  }

  console.log(`Refreshed the vendored payload for ${version}`);

  if (notedChangelog !== changelog) {
    console.log(`Noting ExifTool ${version} in CHANGELOG.md`);
    await writeFile(changelogPath, notedChangelog);
  }
}

if (require.main === module) {
  run();
}

module.exports = {
  renameWithRetry,
  requireMatchingArchiveVersion,
};
