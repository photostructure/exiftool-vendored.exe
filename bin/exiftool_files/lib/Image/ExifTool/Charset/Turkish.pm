#------------------------------------------------------------------------------
# File:         Turkish.pm
#
# Description:  cp1254 to Unicode
#
# Revisions:    2010/01/20 - P. Harvey created
#
# References:   1) http://unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1254.TXT
#
# Notes:        The table omits 1-byte characters with the same values as Unicode
#------------------------------------------------------------------------------
use strict;

%Image::ExifTool::Charset::Turkish = (
  0x80 => 0x20ac, 0x82 => 0x201a, 0x83 => 0x0192, 0x84 => 0x201e,
  0x85 => 0x2026, 0x86 => 0x2020, 0x87 => 0x2021, 0x88 => 0x02c6,
  0x89 => 0x2030, 0x8a => 0x0160, 0x8b => 0x2039, 0x8c => 0x0152,
  0x91 => 0x2018, 0x92 => 0x2019, 0x93 => 0x201c, 0x94 => 0x201d,
  0x95 => 0x2022, 0x96 => 0x2013, 0x97 => 0x2014, 0x98 => 0x02dc,
  0x99 => 0x2122, 0x9a => 0x0161, 0x9b => 0x203a, 0x9c => 0x0153,
  0x9f => 0x0178, 0xd0 => 0x011e, 0xdd => 0x0130, 0xde => 0x015e,
  0xf0 => 0x011f, 0xfd => 0x0131, 0xfe => 0x015f,
);

1; # end
