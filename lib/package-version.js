// @ts-check

/**
 * Return ExifTool version `exiftoolVersion`'s major and minor as numbers.
 * ExifTool 14.05 is [14, 5], and its package versions are 14.5.x: SemVer
 * forbids the leading zero, and npm rewrites 14.05.0 to 14.5.0.
 *
 * @param {string} exiftoolVersion such as "14.05", from `exiftool -ver`
 * @returns {[number, number]}
 */
function exiftoolMajorMinor(exiftoolVersion) {
  const match = /^(\d+)\.(\d+)$/.exec(exiftoolVersion);
  if (match == null) {
    throw new Error(`Invalid ExifTool version: ${exiftoolVersion}`);
  }
  return [Number(match[1]), Number(match[2])];
}

/**
 * True when package version `packageVersion`'s major and minor are ExifTool
 * version `exiftoolVersion`'s, compared as numbers.
 *
 * @param {string} packageVersion
 * @param {string} exiftoolVersion
 */
function packageFollowsExifTool(packageVersion, exiftoolVersion) {
  const [major, minor] = exiftoolMajorMinor(exiftoolVersion);
  const match = /^(\d+)\.(\d+)\.\d+(?:-pre)?$/.exec(packageVersion);
  return (
    match != null && Number(match[1]) === major && Number(match[2]) === minor
  );
}

/**
 * Return the package version that npm must write to make the package and
 * lockfile describe the vendored archive, or null when they already agree.
 *
 * @param {string} packageVersion
 * @param {{ version?: unknown, packages?: Record<string, { version?: unknown }> }} lock
 * @param {string} archiveVersion
 */
function requiredPackageVersionRepair(packageVersion, lock, archiveVersion) {
  if (!packageFollowsExifTool(packageVersion, archiveVersion)) {
    const [major, minor] = exiftoolMajorMinor(archiveVersion);
    return `${major}.${minor}.0-pre`;
  }
  return lock.version === packageVersion &&
    lock.packages?.[""].version === packageVersion
    ? null
    : packageVersion;
}

module.exports = {
  exiftoolMajorMinor,
  packageFollowsExifTool,
  requiredPackageVersionRepair,
};
