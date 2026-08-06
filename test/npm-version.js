const assert = require("node:assert/strict");
const { requireSupportedNpmVersion } = require("../scripts/check-npm-version");

describe("npm version guard", () => {
  it("accepts npm releases that enforce min-release-age", () => {
    assert.strictEqual(requireSupportedNpmVersion("npm/11.10.0"), "11.10.0");
    assert.strictEqual(
      requireSupportedNpmVersion("node/v26.6.0 npm/12.0.0 linux x64"),
      "12.0.0",
    );
  });

  it("rejects npm releases that ignore min-release-age", () => {
    assert.throws(
      () => requireSupportedNpmVersion("npm/11.9.9 node/v24.0.0"),
      /npm 11\.10\.0 or later is required/,
    );
    assert.throws(
      () => requireSupportedNpmVersion("npm/10.9.4 node/v22.0.0"),
      /npm 11\.10\.0 or later is required/,
    );
  });

  it("rejects an invocation outside an npm script", () => {
    assert.throws(
      () => requireSupportedNpmVersion(""),
      /run this check through an npm script/,
    );
  });
});
