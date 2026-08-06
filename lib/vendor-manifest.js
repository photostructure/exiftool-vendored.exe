// @ts-check

const ManifestFields = [
  "version",
  "sourceUrl",
  "platform",
  "architecture",
  "filename",
  "size",
  "sha256",
];

/**
 * @param {Record<string, unknown> | null | undefined} actual
 * @param {Record<string, unknown>} expected
 */
function matchesVendorManifest(actual, expected) {
  return (
    actual != null &&
    ManifestFields.every((field) => actual[field] === expected[field])
  );
}

module.exports = { matchesVendorManifest };
