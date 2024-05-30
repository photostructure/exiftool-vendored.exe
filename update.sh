#!/bin/bash -ex

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
  git stash -u
  git checkout master
  git pull
)

# Everything goes into bin/ -- make sure we're starting fresh:
rm -rf bin

# Pull down Oliver's ExifTool bundle, but delete all the ExifTool source and
# replace it with the latest build from github source:

mkdir -p .dl
DEST=.dl/et.zip
if [ ! -f $DEST ]; then
  curl -o $DEST https://oliverbetz.de/cms/files/Artikel/ExifTool-for-Windows/exiftool-12.82_64.zip
fi
echo "89a43e0e3c1b3145e44bc6b56ea66baddf35af8aed9828afcaf7ebfaebdd9998 $DEST" | sha256sum -c

unzip -q $DEST -d bin
(
  cd bin/exiftool_files
  rm -rf arg_files config_files fmt_files html t Changes exiftool* LICENSE README readme_windows.txt selftest.pl windows_exiftool lib/Image/ExifTool*
)

# We expect lower case:
mv bin/ExifTool.exe bin/exiftool.exe
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
