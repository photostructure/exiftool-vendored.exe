# exiftool-vendored.exe

Provides the win32 distribution of [ExifTool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to [node](https://nodejs.org/en/).

[![npm version](https://img.shields.io/npm/v/exiftool-vendored.exe.svg)](https://www.npmjs.com/package/exiftool-vendored.exe)
[![Build & Release](https://github.com/photostructure/exiftool-vendored.exe/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/photostructure/exiftool-vendored.exe/actions/workflows/build.yml)

## Usage

**See
[exiftool-vendored](https://github.com/photostructure/exiftool-vendored.js) for
performant, type-safe access to this binary.**

## Vendor patches

The vendored payload includes downstream changes from every
[`patches/*.patch`](https://github.com/photostructure/exiftool-vendored.exe/tree/main/patches)
file. The update script applies them in lexical filename order after verifying
and extracting the official ExifTool archive. Patch application uses zero
fuzz, so every context line in each hunk must match exactly. If those context
lines change upstream, the update fails instead of applying the patch
approximately. The manifest records a hash of the ordered patch set. Updating
the vendored payload on Windows requires GNU `patch` from Git for Windows.
When no downstream changes are required, `patches/` may be absent and the
manifest records the SHA-256 fingerprint of the empty patch set.

The current
[`exiftool-stdin-eof.patch`](https://github.com/photostructure/exiftool-vendored.exe/blob/main/patches/exiftool-stdin-eof.patch)
makes stay-open ExifTool exit when its piped or socket stdin closes, while
preserving append-after-EOF polling for regular files. The change is
[reported upstream in exiftool/exiftool#458](https://github.com/exiftool/exiftool/issues/458)
but is not yet included in a released ExifTool version.

If an ExifTool update causes a patch to fail, review the upstream change. Then
refresh the patch if it is still needed, or remove it if upstream now provides
the same behavior. Removing the final patch may also remove `patches/`. Do not
relax the patch options or bypass the failure. Run the full test suite and
commit the patch, vendored source, and manifest changes together.

## Thanks to Phil Harvey and Oliver Betz!

Phil Harvey has been [working tirelessly on ExifTool since 2003](https://exiftool.org/ancient_history.html).

This module uses the new (as of version 12.88) official Windows installation, which depends on [Oliver Betz's portable Perl
launcher](https://oliverbetz.de/pages/Artikel/Portable-Perl-Applications) and Strawberry Perl. [Read more
here.](https://oliverbetz.de/pages/Artikel/ExifTool-for-Windows)

## Versioning

This package exposes the version of ExifTool it vendors, and adds a patch number, if necessary, to follow SemVer.
