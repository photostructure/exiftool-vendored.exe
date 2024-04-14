#!/bin/bash -ex

# Verification of Oliver Betz's package

# SO: what's this?

# This exercise is to prove that Oliver Betz's package of ExifTool is based on
# Strawberry Perl and cpan contents.

# Unfortunately, paths are slightly different for a number of files, and there
# are (expected) edits that don't matter to us (like the stripping of perl
# documentation), so this is a bit more involved than just `diff -r this that`.

mkdir -p .dl
cd .dl

curl -o strawberry-perl-5.32.1.1-64bit-portable.zip https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit-portable.zip

# Verify we're playing with what we expected:
echo '692646105b0f5e058198a852dc52a48f1cebcaf676d63bbdeae12f4eaee9bf5c strawberry-perl-5.32.1.1-64bit-portable.zip' | sha256sum -c

curl -o exiftool-12.82_64.zip https://oliverbetz.de/cms/files/Artikel/ExifTool-for-Windows/exiftool-12.82_64.zip
# Verify we're playing with what we expected:
echo '89a43e0e3c1b3145e44bc6b56ea66baddf35af8aed9828afcaf7ebfaebdd9998 exiftool-12.82_64.zip' | sha256sum -c

# ob = Oliver Betz
unzip exiftool-12.82_64.zip -d ob

# sp = Strawberry Perl
unzip strawberry-perl-5.32.1.1-64bit-portable.zip -d sp

# We replace the exiftool code and strip out the docs and the tests, so clean
# those out now:

(
  cd ob/exiftool_files
  rm -rf arg_files config_files fmt_files html t Changes exiftool* LICENSE README readme_windows.txt selftest.pl windows_exiftool lib/Image Licenses_Strawberry_Perl.zip
)

# And let's not worry about *.pod:
find "$(pwd)" -name \*.pod -print0 | xargs -0 rm

# The ob code has had some PODs stripped, so we need to do that too:
find "$(pwd)" -name \*.pm -print0 | xargs -0 chmod +w
find "$(pwd)" -name \*.pm -print0 | xargs -0 --max-args=1 --max-procs=16 ../.pod-strip.pl

# I don't care if it's in sp/perl/lib or sp/perl/lib/vendor:
cp -r sp/perl/vendor/lib/* sp/perl/lib
cp sp/c/bin/liblzma-5__.dll sp/perl

# DLLs are in a different place. Move the strawberry perl ones:
cp sp/perl/bin/*.{dll,exe} sp/perl

# Several packages aren't in the strawberry perl archive:
cpan Win32::FindFile
mkdir -p sp/perl/lib/auto/Win32
cp "$(find ~/perl5 $PERL5LIB -wholename \*/auto/Win32/FindFile.xs.dll)" sp/perl/lib/auto/Win32/
mkdir -p sp/perl/lib/Win32/
cp "$(find ~/perl5 $PERL5LIB -wholename \*/Win32/FindFile.pm)" sp/perl/lib/Win32/

cpan File::RandomAccess
mkdir -p sp/perl/lib/File
cp "$(find ~/perl5 $PERL5LIB -wholename \*/File/RandomAccess.pm)" sp/perl/lib/File/

for ea in Compress Uncompress; do
  cpan IO::$ea::Brotli
  mkdir -p sp/perl/lib/auto/IO/$ea/Brotli/
  cp "$(find ~/perl5 $PERL5LIB -wholename \*/auto/IO/$ea/Brotli/Brotli.xs.dll)" sp/perl/lib/auto/IO/$ea/Brotli
  mkdir -p sp/perl/lib/IO/$ea/
  cp "$(find ~/perl5 $PERL5LIB -wholename \*/$ea/Brotli.pm)" sp/perl/lib/IO/$ea/
done

# We don't care about lines that are due to POD being deleted (the `#line 1234`
# pattern), nor do we care about files that are only in Strawberry Perl:
diff -wr -I '^\#line [0-9]' ob/exiftool_files sp/perl | grep -v "Only in sp/perl"
