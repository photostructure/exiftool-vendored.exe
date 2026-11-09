const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { noteExifToolUpdate } = require("../lib/changelog");

const Header = "# Changelog\n\nSome intro.\n\n";
const LastRelease = "13.60.0";
const Released =
  "## [13.60.0] - 2026-10-28\n\n- 📦 Updated ExifTool to [13.60](https://exiftool.org/history.html#v13.60).\n\n[13.60.0]: https://github.com/photostructure/exiftool-vendored.exe/releases/tag/13.60.0\n";

describe("CHANGELOG.md ExifTool update note", () => {
  it("names the release version and adds the note under a bare Unreleased heading", () => {
    assert.strictEqual(
      noteExifToolUpdate(
        Header + "## [Unreleased]\n\n" + Released,
        LastRelease,
        "13.61",
      ),
      Header +
        "## [Unreleased (13.61.0)]\n\n" +
        "- 📦 Updated ExifTool to [13.61](https://exiftool.org/history.html#v13.61).\n\n" +
        Released,
    );
  });

  it("adds the note to a changelog whose only section is Unreleased", () => {
    assert.strictEqual(
      noteExifToolUpdate(Header + "## [Unreleased]\n", LastRelease, "13.61"),
      Header +
        "## [Unreleased (13.61.0)]\n\n" +
        "- 📦 Updated ExifTool to [13.61](https://exiftool.org/history.html#v13.61).\n",
    );
  });

  it("keeps hand-written notes of a pending patch release below the ExifTool note", () => {
    assert.strictEqual(
      noteExifToolUpdate(
        Header +
          "## [Unreleased (patch)]\n\n- 🐞 Fixed a thing.\n\n" +
          Released,
        LastRelease,
        "13.61",
      ),
      Header +
        "## [Unreleased (13.61.0)]\n\n" +
        "- 📦 Updated ExifTool to [13.61](https://exiftool.org/history.html#v13.61).\n" +
        "- 🐞 Fixed a thing.\n\n" +
        Released,
    );
  });

  it("replaces the note of an earlier update that was never released", () => {
    assert.strictEqual(
      noteExifToolUpdate(
        Header +
          "## [Unreleased (13.61.0)]\n\n" +
          "- 🐞 Fixed a thing.\n" +
          "- 📦 Updated ExifTool to [13.61](https://exiftool.org/history.html#v13.61).\n\n" +
          Released,
        LastRelease,
        "13.62",
      ),
      Header +
        "## [Unreleased (13.62.0)]\n\n" +
        "- 🐞 Fixed a thing.\n" +
        "- 📦 Updated ExifTool to [13.62](https://exiftool.org/history.html#v13.62).\n\n" +
        Released,
    );
  });

  it("folds a pending package-only release into the ExifTool update", () => {
    assert.strictEqual(
      noteExifToolUpdate(
        Header +
          "## [Unreleased (13.60.1)]\n\n- 🐞 Fixed a thing.\n\n" +
          Released,
        LastRelease,
        "13.61",
      ),
      Header +
        "## [Unreleased (13.61.0)]\n\n" +
        "- 📦 Updated ExifTool to [13.61](https://exiftool.org/history.html#v13.61).\n" +
        "- 🐞 Fixed a thing.\n\n" +
        Released,
    );
  });

  it("drops a zero-padded minor from the heading but keeps it in the note", () => {
    // changelog-release-action v0.3.0's bump refuses "14.05.0" ("an exact
    // version without leading zeros"); ExifTool names the release 14.05.
    assert.strictEqual(
      noteExifToolUpdate(Header + "## [Unreleased]\n", LastRelease, "14.05"),
      Header +
        "## [Unreleased (14.5.0)]\n\n" +
        "- 📦 Updated ExifTool to [14.05](https://exiftool.org/history.html#v14.05).\n",
    );
  });

  it("keeps a zero-padded note when the update runs again", () => {
    const once = noteExifToolUpdate(
      Header + "## [Unreleased]\n",
      LastRelease,
      "14.05",
    );
    assert.strictEqual(noteExifToolUpdate(once, LastRelease, "14.05"), once);
  });

  it("changes nothing when the update runs again for the same version", () => {
    const once = noteExifToolUpdate(
      Header + "## [Unreleased]\n\n" + Released,
      LastRelease,
      "13.61",
    );
    assert.strictEqual(noteExifToolUpdate(once, LastRelease, "13.61"), once);
  });

  it("leaves the changelog alone when this ExifTool is already released", () => {
    const text = Header + "## [Unreleased]\n\n" + Released;
    assert.strictEqual(noteExifToolUpdate(text, "13.60.0", "13.60"), text);
    assert.strictEqual(noteExifToolUpdate(text, "14.5.0", "14.05"), text);
    assert.strictEqual(
      noteExifToolUpdate("not a changelog", "13.60.1", "13.60"),
      "not a changelog",
    );
  });

  it("asks for an Unreleased heading when there is none", () => {
    assert.throws(
      () => noteExifToolUpdate(Header + Released, LastRelease, "13.61"),
      /CHANGELOG\.md has no "## \[Unreleased\]" heading/,
    );
  });

  for (const bump of ["minor", "major"]) {
    it(`refuses an Unreleased heading that names a ${bump} release`, () => {
      assert.throws(
        () =>
          noteExifToolUpdate(
            Header +
              `## [Unreleased (${bump})]\n\n- ✨ Added a thing.\n\n` +
              Released,
            LastRelease,
            "13.61",
          ),
        new RegExp(
          `Line 5 of CHANGELOG\\.md names a ${bump} release.*major\\.minor is the vendored ExifTool version.*"## \\[Unreleased \\(13\\.61\\.0\\)\\]"`,
        ),
      );
    });
  }

  it("accepts the repository's own CHANGELOG.md", () => {
    const text = readFileSync(join(__dirname, "..", "CHANGELOG.md"), "utf8");
    // Hand-written notes may sit above the ExifTool line, so look for the line
    // anywhere in the Unreleased section rather than right after the heading.
    const section =
      /^## \[Unreleased \(99\.1\.0\)\]\n([\s\S]*?)(?=^## |(?![\s\S]))/m.exec(
        noteExifToolUpdate(text, LastRelease, "99.1"),
      )?.[1];
    assert.ok(section != null, "no ## [Unreleased (99.1.0)] section");
    assert.match(
      section,
      /^- 📦 Updated ExifTool to \[99\.1\]\(https:\/\/exiftool\.org\/history\.html#v99\.1\)\.$/m,
    );
  });
});
