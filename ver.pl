#!/usr/bin/env perl

use strict;
use File::Spec;
use FindBin;

# This reproduces `exiftool -ver` output (but we don't have the `exiftool`
# wrapper, so we have to reproduce it here). This is only used if non-windows
# platforms run update-exiftool.js.

use lib File::Spec->catdir($FindBin::Bin, 'bin', 'exiftool_files', 'lib');
use Image::ExifTool;
print "$Image::ExifTool::VERSION$Image::ExifTool::RELEASE";
