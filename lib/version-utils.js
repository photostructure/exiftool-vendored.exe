// @ts-check
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

async function fetchWithRetry(url, options = {}) {
  const maxRetries = 3;
  const timeout = 30000; // 30 seconds
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);
      
      const response = await fetch(url, {
        ...options,
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      return response;
    } catch (error) {
      console.log(`Fetch attempt ${i + 1} failed:`, error.message);
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 2000 * (i + 1))); // Exponential backoff
    }
  }
}

async function getLatestExifToolVersion() {
  try {
    // Try GitHub tags API first (cleaner than RSS)
    const response = await fetchWithRetry('https://api.github.com/repos/exiftool/exiftool/tags');
    const tags = await response?.json();
    
    if (tags && tags.length > 0) {
      // Get the first (latest) tag
      const latestTag = tags[0].name;
      // Add .0 patch version if it's just major.minor
      return latestTag.includes('.') && latestTag.split('.').length === 2 ? latestTag + '.0' : latestTag;
    }
  } catch (error) {
    console.log('GitHub API failed, falling back to RSS feed:', error.message);
  }

  // Fallback to RSS feed
  const xml2js = require('xml2js');
  const response = await fetchWithRetry("https://exiftool.org/rss.xml");
  const xmlData = await response?.text();
  const parser = new xml2js.Parser();
  const xmlDoc = await parser.parseStringPromise(xmlData);
  const items = xmlDoc.rss.channel[0].item;
  
  for (const item of items) {
    const title = item.title[0];
    const version = /\b(\d{2}\.\d+)\b/.exec(title);
    if (version && version[1]) {
      return version[1] + '.0';
    }
  }
  
  throw new Error('No version found in RSS feed');
}

function getCurrentVersion() {
  const packagePath = join(__dirname, '..', 'package.json');
  const packageJson = JSON.parse(readFileSync(packagePath, 'utf8'));
  return packageJson.version.replace('-pre', '');
}

async function checkForUpdate() {
  const currentVersion = getCurrentVersion();
  const latestVersion = await getLatestExifToolVersion();
  
  return {
    currentVersion,
    latestVersion,
    updateAvailable: currentVersion !== latestVersion
  };
}

module.exports = {
  fetchWithRetry,
  getLatestExifToolVersion,
  getCurrentVersion,
  checkForUpdate
};