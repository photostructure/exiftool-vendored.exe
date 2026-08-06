const assert = require("node:assert/strict");
const { getLatestExifToolVersion } = require("../lib/version-utils");

describe("ExifTool version lookup", () => {
  it("keeps retry and fallback diagnostics out of captured stdout", async () => {
    const stdout = [];
    const stderr = [];
    const originalLog = console.log;
    const originalError = console.error;
    console.log = (...args) => stdout.push(args);
    console.error = (...args) => stderr.push(args);

    try {
      const version = await getLatestExifToolVersion({
        fetchImpl: async (url) => {
          if (url.includes("api.github.com")) {
            throw new Error("simulated GitHub failure");
          }
          return {
            text: async () => `
              <rss><channel><item>
                <title>ExifTool 13.60 is now available</title>
              </item></channel></rss>
            `,
          };
        },
        retryDelayMs: 0,
        timeoutMs: 50,
      });

      assert.strictEqual(version, "13.60");
      assert.deepStrictEqual(stdout, []);
      assert(stderr.length > 0);
    } finally {
      console.log = originalLog;
      console.error = originalError;
    }
  });
});
