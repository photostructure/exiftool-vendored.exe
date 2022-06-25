#!/bin/sh -ex

# Updates to the latest version of exiftool. Assumes we can git clone exiftool
# into the parent directory.

if [ ! -d ../exiftool ]; then
  (
    cd ..
    git clone git@github.com:exiftool/exiftool.git
  )
fi

(
  cd ../exiftool
  git add .
  git stash -u
  git checkout master
  git pull
)

rm -rf bin
mkdir -p bin/exiftool_files

# Pull down Oliver's supplemental files:
mkdir -p .dl
DEST=.dl/pfe.zip
if [ ! -f $DEST ]; then
  curl -o $DEST https://oliverbetz.de/cms/files/Artikel/ExifTool-for-Windows/perl-5.30.0.1_for_ExifTool.zip
fi

if [ "$(sha1sum $DEST | cut -d' ' -f1)" != "1cf1c2293e703bb0cd7673ae051ed08d1eb64952" ]; then
  echo "checksum did not match for $DEST. Exitting."
  rm $DEST
  exit 1
fi

# From https://oliverbetz.de/cms/files/Artikel/Portable-Perl-Applications/ppl.zip
cp -r ppl/pplx.exe bin/exiftool.exe
unzip -q $DEST -d bin

cp -rp ../exiftool/* bin/exiftool_files
(
  cd bin/exiftool_files
  rm -rf t html MANIFEST META* perl-Image-ExifTool.spec validate build_tag_lookup pp_build_exe.args
)

# windows-specific start script
rm bin/exiftool_files/exiftool
mv bin/exiftool_files/windows_exiftool bin/exiftool_files/exiftool.pl

if [ "$(git status --porcelain=v1 2>/dev/null | wc -l)" -eq 0 ]; then
  echo "No-op: already up to date"
else
  # exiftool never has a patch version:
  NEWVER=$(../exiftool/exiftool -ver).0-pre
  yarn version --new-version "$NEWVER"
fi
