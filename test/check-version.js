const assert = require("assert");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");

// Calling process.exit() right after a fetch() aborts the process on Windows:
// undici keeps the TLS socket on a worker thread, and process.exit() races its
// teardown (nodejs/node#56645). The abort is deterministic against a remote
// HTTPS host but does not reproduce against a loopback server, so there is no
// offline test for the crash itself -- guard the pattern instead. The
// check-updates workflow branches on this script's exit code, so an abort here
// reads as "the update check failed."
// `process.exit(2)` and the bare `.catch(process.exit)` this replaced.
const ExitCall = /process\.exit\b(?!Code)/;

/** @param {string[]} parts */
const readCode = (...parts) =>
  readFileSync(join(__dirname, "..", ...parts), "utf8")
    // Comments here discuss the pattern they forbid.
    .replace(/^\s*(\/\/|#).*$/gm, "");

describe("exit codes on Windows", () => {
  it("check-version.js sets process.exitCode rather than exiting", () => {
    const source = readCode("check-version.js");

    assert(!ExitCall.test(source), "process.exit() races undici teardown");
    assert(/process\.exitCode\s*=/.test(source));
  });

  it("the update check workflow sets process.exitCode rather than exiting", () => {
    const workflow = readCode(".github", "workflows", "check-updates.yml");

    assert(!ExitCall.test(workflow), "process.exit() races undici teardown");
    assert(/process\.exitCode\s*=/.test(workflow));
  });
});
