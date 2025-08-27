#!/usr/bin/env node
// @ts-check

const { spawnSync } = require("node:child_process");
const { createHash } = require("node:crypto");
const { createWriteStream, createReadStream } = require("node:fs");
const { mkdir, rm, rename, stat } = require("node:fs/promises");
const { join } = require("node:path");
const { pipeline } = require("node:stream/promises");

const xml2js = require("xml2js");
const extractZip = require("extract-zip");
const { fetchWithRetry } = require("./lib/version-utils");

// Currently is "12.88", but "13.1" is valid.

const VersionRE = /\b([\d\.]{4,})\b/;

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
      (ea) => ea.$.type === "application/zip" && ea.$.url.endsWith("_64.zip"),
    )?.$;
    if (enc != null) break;
  }
  if (enc == null) {
    throw new Error("No enclosure with a valid download link was found");
  }
  return enc;
}

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
    if (e.code !== "ENOENT") {
      throw e;
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
  const enc = await fetchLatestEnclosure();
  const u = new URL(enc.url);
  const basename = u.pathname.split("/").at(-1);
  if (basename == null) {
    throw new Error("Invalid basename from URL: " + enc.url);
  }
  const expectedSha256 = await fetchLatestSHA256(basename);
  const dir = join(__dirname, ".dl");
  const zipPath = await wget(enc.url, basename, dir, expectedSha256);
  const expectedFileSize = parseInt(enc.length);
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
  await extractZip(zipPath, { dir });
  const destDir = join(__dirname, "bin");
  await rm(destDir, {
    recursive: true,
    force: true,
    maxRetries: 5,
    retryDelay: 1000,
  });
  await rename(expectedZipOutDir, destDir);
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
    version = versionResult.stdout.toString().trim();
  } else {
    // On non-Windows platforms, extract version from filename
    const versionMatch = basename.match(/exiftool-(\d+\.\d+)_/);
    if (!versionMatch) {
      throw new Error("Could not extract version from filename: " + basename);
    }
    version = versionMatch[1];
  }

  // Check if there are any pending updates
  const gitStatus = spawnSync("git", ["status", "--porcelain=v1"])
    .stdout.toString()
    .trim();

  if (gitStatus.length === 0) {
    console.log("No-op: already up to date");
  } else {
    // ExifTool never has a patch version
    const pkgVer = version + ".0-pre";
    console.log("Updating package.json to version " + pkgVer);
    // Note: shell: true is required on Windows for npm command to work properly
    spawnSync("npm", ["version", "--no-git-tag-version", pkgVer], {
      shell: true,
    });
  }
}

run();
