#------------------------------------------------------------------------------
# File:         PDFDoc.pm
#
# Description:  PDFDocEncoding to Unicode
#
# Revisions:    2010/10/16 - P. Harvey created
#
# References:   1) http://www.adobe.com/devnet/pdf/pdf_reference.html
#
# Notes:        The table omits 1-byte characters with the same values as Unicode
#               This set re-maps characters with codepoints less than 0x80
#------------------------------------------------------------------------------
use strict;

%Image::ExifTool::Charset::PDFDoc = (
  0x18 => 0x02d8,  0x82 => 0x2021,  0x8c => 0x201e,  0x96 => 0x0152,
  0x19 => 0x02c7,  0x83 => 0x2026,  0x8d => 0x201c,  0x97 => 0x0160,
  0x1a => 0x02c6,  0x84 => 0x2014,  0x8e => 0x201d,  0x98 => 0x0178,
  0x1b => 0x02d9,  0x85 => 0x2013,  0x8f => 0x2018,  0x99 => 0x017d,
  0x1c => 0x02dd,  0x86 => 0x0192,  0x90 => 0x2019,  0x9a => 0x0131,
  0x1d => 0x02db,  0x87 => 0x2044,  0x91 => 0x201a,  0x9b => 0x0142,
  0x1e => 0x02da,  0x88 => 0x2039,  0x92 => 0x2122,  0x9c => 0x0153,
  0x1f => 0x02dc,  0x89 => 0x203a,  0x93 => 0xfb01,  0x9d => 0x0161,
  0x80 => 0x2022,  0x8a => 0x2212,  0x94 => 0xfb02,  0x9e => 0x017e,
  0x81 => 0x2020,  0x8b => 0x2030,  0x95 => 0x0141,  0xa0 => 0x20ac,
);

1; # end
