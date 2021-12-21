#------------------------------------------------------------------------------
# File:         Greek.pm
#
# Description:  cp1253 to Unicode
#
# Revisions:    2010/01/20 - P. Harvey created
#
# References:   1) http://unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP1253.TXT
#
# Notes:        The table omits 1-byte characters with the same values as Unicode
#------------------------------------------------------------------------------
use strict;

%Image::ExifTool::Charset::Greek = (
  0x80 => 0x20ac, 0x82 => 0x201a, 0x83 => 0x0192, 0x84 => 0x201e,
  0x85 => 0x2026, 0x86 => 0x2020, 0x87 => 0x2021, 0x89 => 0x2030,
  0x8b => 0x2039, 0x91 => 0x2018, 0x92 => 0x2019, 0x93 => 0x201c,
  0x94 => 0x201d, 0x95 => 0x2022, 0x96 => 0x2013, 0x97 => 0x2014,
  0x99 => 0x2122, 0x9b => 0x203a, 0xa1 => 0x0385, 0xa2 => 0x0386,
  0xaf => 0x2015, 0xb4 => 0x0384, 0xb8 => 0x0388, 0xb9 => 0x0389,
  0xba => 0x038a, 0xbc => 0x038c, 0xbe => 0x038e, 0xbf => 0x038f,
  0xc0 => 0x0390, 0xc1 => 0x0391, 0xc2 => 0x0392, 0xc3 => 0x0393,
  0xc4 => 0x0394, 0xc5 => 0x0395, 0xc6 => 0x0396, 0xc7 => 0x0397,
  0xc8 => 0x0398, 0xc9 => 0x0399, 0xca => 0x039a, 0xcb => 0x039b,
  0xcc => 0x039c, 0xcd => 0x039d, 0xce => 0x039e, 0xcf => 0x039f,
  0xd0 => 0x03a0, 0xd1 => 0x03a1, 0xd3 => 0x03a3, 0xd4 => 0x03a4,
  0xd5 => 0x03a5, 0xd6 => 0x03a6, 0xd7 => 0x03a7, 0xd8 => 0x03a8,
  0xd9 => 0x03a9, 0xda => 0x03aa, 0xdb => 0x03ab, 0xdc => 0x03ac,
  0xdd => 0x03ad, 0xde => 0x03ae, 0xdf => 0x03af, 0xe0 => 0x03b0,
  0xe1 => 0x03b1, 0xe2 => 0x03b2, 0xe3 => 0x03b3, 0xe4 => 0x03b4,
  0xe5 => 0x03b5, 0xe6 => 0x03b6, 0xe7 => 0x03b7, 0xe8 => 0x03b8,
  0xe9 => 0x03b9, 0xea => 0x03ba, 0xeb => 0x03bb, 0xec => 0x03bc,
  0xed => 0x03bd, 0xee => 0x03be, 0xef => 0x03bf, 0xf0 => 0x03c0,
  0xf1 => 0x03c1, 0xf2 => 0x03c2, 0xf3 => 0x03c3, 0xf4 => 0x03c4,
  0xf5 => 0x03c5, 0xf6 => 0x03c6, 0xf7 => 0x03c7, 0xf8 => 0x03c8,
  0xf9 => 0x03c9, 0xfa => 0x03ca, 0xfb => 0x03cb, 0xfc => 0x03cc,
  0xfd => 0x03cd, 0xfe => 0x03ce,
);

1; # end
