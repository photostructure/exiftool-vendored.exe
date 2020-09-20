const fs = require("fs");
var assert = require("assert");

describe("exported path", () => {
  it("is a valid path to a file", () => {
    const path = require("..");
    assert(fs.existsSync(path));
  });
});
