const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { requireSupportedNpmVersion } = require("../scripts/check-npm-version");
const pkg = require("../package.json");

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

  it("rejects old npm before a bare install can resolve dependencies", () => {
    const npmrc = readFileSync(".npmrc", "utf8");

    assert.deepStrictEqual(pkg.devEngines.packageManager, {
      name: "npm",
      version: ">=11.10.0",
      onFail: "error",
    });
    assert.match(npmrc, /^min-release-age=14$/m);
  });
});
