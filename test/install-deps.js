const assert = require("node:assert/strict");
const { npmInstallArgs } = require("../scripts/install-deps");
const pkg = require("../package.json");

describe("dependency install after npm-check-updates", () => {
  it("installs normally on Windows", () => {
    assert.deepStrictEqual(npmInstallArgs("win32"), ["install"]);
  });

  it("forces past the root package's os field elsewhere", () => {
    assert.deepStrictEqual(npmInstallArgs("linux"), ["install", "--force"]);
    assert.deepStrictEqual(npmInstallArgs("darwin"), ["install", "--force"]);
  });

  it("lets update:deps run the install instead of npm-check-updates", () => {
    assert.match(pkg.scripts["update:deps"], /--install never/);
    assert.match(pkg.scripts["update:deps"], /node scripts\/install-deps\.js/);
  });
});
