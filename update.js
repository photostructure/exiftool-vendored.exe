#!/usr/bin/env node
// @ts-check

const { spawnSync } = require("node:child_process");
const { createHash } = require("node:crypto");
const { createWriteStream, createReadStream } = require("node:fs");
const { mkdir, rm, rename, stat } = require("node:fs/promises");
const { join } = require("node:path");
const { pipeline } = require("node:stream");
const { promisify } = require("node:util");

const xml2js = require("xml2js");
const unzipper = require("unzipper");

// Currently is "12.88", but "13.1" is valid.

const VersionRE = /\b([\d\.]{4,})\b/;

const asyncPipeline = promisify(pipeline);

async function fetchLatestEnclosure() {
  const response = await fetch("https://exiftool.org/rss.xml");
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
  const response = await fetch("https://exiftool.org/checksums.txt");
  const text = await response.text();
  for (const line of text.split("\n")) {
    if (line.startsWith("SHA256") && line.includes(basename)) {
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
  const response = await fetch(url);
  if (response.body == null) {
    throw new Error("Response body from fetch(" + url + ") is null");
  }
  await asyncPipeline(response.body, createWriteStream(out));
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
  await rm(expectedZipOutDir, { recursive: true, force: true });
  await asyncPipeline(
    createReadStream(zipPath),
    unzipper.Extract({ path: dir }),
  );
  const destDir = join(__dirname, "bin");
  await rm(destDir, { recursive: true, force: true });
  await rename(expectedZipOutDir, destDir);
  await rename(
    join(__dirname, "bin", "exiftool(-k).exe"),
    join(__dirname, "bin", "exiftool.exe"),
  );

  const version = spawnSync(join(__dirname, "bin", "exiftool.exe"), ["-ver"])
    .stdout.toString()
    .trim();

  const pkgVer = version + ".0-pre";

  console.log("Updating package.json to version " + pkgVer);

  spawnSync("yarn", ["version", " --new-version", pkgVer], {
    shell: true,
    // UGLY HACK https://github.com/yarnpkg/yarn/issues/1228
    env: { YARN_VERSION_GIT_TAG: "" },
  });
}

run();
