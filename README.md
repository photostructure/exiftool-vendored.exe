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
and extracting the official ExifTool archive. Patch filenames start with the
date the patch was written (`YYYY-MM-DD-description.patch`), so that order is
the order the patches were written. Patch application uses zero
fuzz, so every context line in each hunk must match exactly. If those context
lines change upstream, the update fails instead of applying the patch
approximately. Updating the vendored payload on Windows requires GNU `patch`
from Git for Windows. When no downstream changes are required, `patches/` may
be absent.

[`2026-08-07-exiftool-stdin-eof.patch`](https://github.com/photostructure/exiftool-vendored.exe/blob/main/patches/2026-08-07-exiftool-stdin-eof.patch)
makes stay-open ExifTool exit when its piped or socket stdin closes, while
preserving append-after-EOF polling for regular files. The change is
[reported upstream in exiftool/exiftool#458](https://github.com/exiftool/exiftool/issues/458)
but is not yet included in a released ExifTool version.

[`2026-09-24-exiftool-imagehash-progress.patch`](https://github.com/photostructure/exiftool-vendored.exe/blob/main/patches/2026-09-24-exiftool-imagehash-progress.patch)
adds an `ImageHashProgress` API option. Set to a number of seconds, it makes
ExifTool print `{progress:BYTES}` to stderr at most that often while it
computes `ImageDataHash`, where BYTES counts the image data hashed so far for
the current file. exiftool-vendored uses it to tell a slow read of a large
file from a stalled one. ExifTool builds without the patch ignore the option.

Progress prints only between reads, when ExifTool adds a block to the digest.
Most formats hash in 64 KiB reads, and JPEG scan data hashes between `0xff`
bytes. QuickTime and MP4 audio and video samples are the exception: ExifTool
reads each sample chunk whole. In sample files measured on 2026-09-24, the
largest chunk was 0.3 to 3.1 MB for phone and action-camera video, and 28.2 MB
for a 302 MB Fujifilm GFX100RF MOV. That chunk trips exiftool-vendored's
default 30-second task timeout only on storage slower than about 1 MB/s, and
PhotoStructure's 2-minute timeout below about 0.24 MB/s. USB 2 drives, SD
cards, and network shares are faster than that, so the patch doesn't split
these reads. If it ever needs to, `ProcessSamples` in `QuickTimeStream.pl` can
hash `vide` and `soun` samples through ExifTool's 64 KiB `ImageDataHash()`
reader instead of one read per chunk.

If an ExifTool update causes a patch to fail, review the upstream change. Then
refresh the patch if it is still needed, or remove it if upstream now provides
the same behavior. Removing the final patch may also remove `patches/`. Do not
relax the patch options or bypass the failure. Run the full test suite and
commit the patch and vendored source changes together.

## Thanks to Phil Harvey and Oliver Betz!

Phil Harvey has been [working tirelessly on ExifTool since 2003](https://exiftool.org/ancient_history.html).

This module uses the new (as of version 12.88) official Windows installation, which depends on [Oliver Betz's portable Perl
launcher](https://oliverbetz.de/pages/Artikel/Portable-Perl-Applications) and Strawberry Perl. [Read more
here.](https://oliverbetz.de/pages/Artikel/ExifTool-for-Windows)

## Versioning

This package exposes the version of ExifTool it vendors, and adds a patch number, if necessary, to follow SemVer.
