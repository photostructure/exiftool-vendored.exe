// @ts-check
const { spawnSync } = require("node:child_process");
const { existsSync } = require("node:fs");
const { join } = require("node:path");

async function fetchWithRetry(url, options = {}) {
  const maxRetries = 3;
  const timeout = 30000; // 30 seconds

  for (let i = 0; i < maxRetries; i++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
      return response;
    } catch (error) {
      console.log(`Fetch attempt ${i + 1} failed:`, error.message);
      if (i === maxRetries - 1) throw error;
      await new Promise((resolve) => setTimeout(resolve, 2000 * (i + 1))); // Exponential backoff
    }
  }
  throw new Error("non-positive maxRetries");
}

async function getLatestExifToolVersion() {
  try {
    // Try GitHub tags API first (cleaner than RSS)
    const response = await fetchWithRetry(
      "https://api.github.com/repos/exiftool/exiftool/tags"
    );
    const tags = await response?.json();

    if (tags && tags.length > 0) {
      // Get the first (latest) tag
      return tags[0].name;
    }
  } catch (error) {
    console.log("GitHub API failed, falling back to RSS feed:", error.message);
  }

  // Fallback to RSS feed
  const xml2js = require("xml2js");
  const response = await fetchWithRetry("https://exiftool.org/rss.xml");
  const xmlData = await response.text();
  const parser = new xml2js.Parser();
  const xmlDoc = await parser.parseStringPromise(xmlData);
  const items = xmlDoc.rss.channel[0].item;

  for (const item of items) {
    const title = item.title[0];
    const version = /\b(\d{2}\.\d+)\b/.exec(title);
    if (version && version[1]) {
      return version[1];
    }
  }

  throw new Error("No version found in RSS feed");
}

function getCurrentVersion() {
  const exiftoolPath = join(__dirname, "..", "bin", "exiftool.exe");

  // If no binary exists, return null (needs initial install)
  if (!existsSync(exiftoolPath)) {
    return null;
  }

  // On Windows, run the binary to get version
  if (process.platform === "win32") {
    // if this fails, let the error propagate -- something is amiss!
    const versionResult = spawnSync(exiftoolPath, ["-ver"]);
    if (!versionResult.error && versionResult.stdout) {
      return versionResult.stdout.toString().trim();
    }
  }

  // On non-Windows or if binary fails, use our Perl script
  try {
    const versionResult = spawnSync("perl", [join(__dirname, "..", "ver.pl")]);
    if (!versionResult.error && versionResult.stdout) {
      return versionResult.stdout.toString().trim();
    }
  } catch (error) {
    // Perl method failed
  }

  return null;
}

async function checkForUpdate() {
  const currentVersion = getCurrentVersion();
  const latestVersion = await getLatestExifToolVersion();

  return {
    currentVersion: currentVersion || "none",
    latestVersion,
    updateAvailable: currentVersion !== latestVersion,
  };
}

module.exports = {
  fetchWithRetry,
  getLatestExifToolVersion,
  getCurrentVersion,
  checkForUpdate,
};
