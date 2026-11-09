// @ts-check

// Writes update-exiftool.js's note into CHANGELOG.md, so the line the release
// publishes is in the diff the maintainer commits. The release workflow reads
// the version from the Unreleased heading with
// photostructure/changelog-release-action.

const { packageFollowsExifTool } = require("./package-version");

const UnreleasedRE = /^## \[Unreleased(?: \((.*)\))?\]$/;
const ExifToolNoteRE = /^- .*Updated ExifTool to /;

/**
 * Returns CHANGELOG.md's text with a note for ExifTool `exiftoolVersion`, the
 * archive's version such as "13.61" or "14.05", under
 * `## [Unreleased (X.Y.0)]`.
 *
 * package.json keeps the last released version until the release workflow
 * sets the next one, so a `packageVersion` that already follows
 * `exiftoolVersion` means this ExifTool is released, and the text comes back
 * unchanged. The note keeps `exiftoolVersion`'s spelling because ExifTool's
 * history anchors keep the zero in 14.05. The heading names the exact
 * version the release takes. It replaces `patch` or an earlier version,
 * because a pending package-only release or an earlier unreleased update
 * ships as this ExifTool's X.Y.0. An earlier unreleased update's note is
 * replaced in place.
 *
 * @param {string} text
 * @param {string} packageVersion
 * @param {string} exiftoolVersion
 */
function noteExifToolUpdate(text, packageVersion, exiftoolVersion) {
  if (packageFollowsExifTool(packageVersion, exiftoolVersion)) return text;
  // ExifTool 14.05 ships as 14.5.0: npm drops the leading zero, and the action
  // refuses a heading that keeps it.
  const [major, minor] = exiftoolVersion.split(".");
  const heading = `## [Unreleased (${major}.${Number(minor)}.0)]`;

  const lines = text.split("\n");
  const index = lines.findIndex((line) => UnreleasedRE.test(line));
  if (index === -1) {
    throw new Error(
      'CHANGELOG.md has no "## [Unreleased]" heading. Add it above the newest release, then run the update again.',
    );
  }
  const bump = UnreleasedRE.exec(lines[index])?.[1];
  if (bump != null && bump !== "patch" && !/^\d+\.\d+\.\d+$/.test(bump)) {
    throw new Error(
      `Line ${index + 1} of CHANGELOG.md names a ${bump} release, but this package's major.minor is the vendored ExifTool version. Change it to "${heading}", then run the update again.`,
    );
  }
  lines[index] = heading;

  const note = `- 📦 Updated ExifTool to [${exiftoolVersion}](https://exiftool.org/history.html#v${exiftoolVersion}).`;
  let end = index + 1;
  while (end < lines.length && !lines[end].startsWith("## ")) end++;
  const section = lines.slice(index + 1, end);
  const earlier = section.findIndex((line) => ExifToolNoteRE.test(line));
  const first = section.findIndex((line) => /\S/.test(line));
  if (earlier !== -1) {
    section[earlier] = note;
  } else if (first !== -1) {
    section.splice(first, 0, note);
  } else {
    section.splice(0, section.length, "", note, "");
  }
  lines.splice(index + 1, end - index - 1, ...section);
  return lines.join("\n");
}

module.exports = { noteExifToolUpdate };
