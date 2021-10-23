#!/usr/bin/perl -w
#------------------------------------------------------------------------------
# File:         windows_exiftool
#
# Description:  exiftool version for Windows EXE bundle
#
# Revisions:    Nov. 12/03 - P. Harvey Created
#               (See html/history.html for revision history)
#------------------------------------------------------------------------------
use strict;
require 5.004;

my $version = '12.33';

# add our 'lib' directory to the include list BEFORE 'use Image::ExifTool'
my $exeDir;
BEGIN {
    # (undocumented -xpath option added in 11.91, must come before other options)
    $Image::ExifTool::exePath = @ARGV && lc($ARGV[0]) eq '-xpath' && shift() ? $^X : $0;
    # get exe directory
    $exeDir = ($Image::ExifTool::exePath =~ /(.*)[\\\/]/) ? $1 : '.';
    # (no link following for Windows exe version)
    # add lib directory at start of include path
    unshift @INC, ($0 =~ /(.*)[\\\/]/) ? "$1/lib" : './lib';
    # load or disable config file if specified
    if (@ARGV and lc($ARGV[0]) eq '-config') {
        shift;
        $Image::ExifTool::configFile = shift;
    }
}
use Image::ExifTool qw{:Public};

# function prototypes
sub SigInt();
sub SigCont();
sub Cleanup();
sub GetImageInfo($$);
sub SetImageInfo($$$);
sub DoHardLink($$$$$);
sub CleanXML($);
sub EncodeXML($);
sub FormatXML($$$);
sub EscapeJSON($;$);
sub FormatJSON($$$);
sub PrintCSV();
sub AddGroups($$$$);
sub ConvertBinary($);
sub IsEqual($$);
sub Infile($;$);
sub AddSetTagsFile($;$);
sub DoSetFromFile($$$);
sub CleanFilename($);
sub SetWindowTitle($);
sub ProcessFiles($;$);
sub ScanDir($$;$);
sub FindFileWindows($$);
sub FileNotFound($);
sub PreserveTime();
sub AbsPath($);
sub MyConvertFileName($$);
sub SuggestedExtension($$$);
sub LoadPrintFormat($);
sub FilenameSPrintf($;$@);
sub NextUnusedFilename($;$);
sub CreateDirectory($);
sub OpenOutputFile($;@);
sub AcceptFile($);
sub SlurpFile($$);
sub FilterArgfileLine($);
sub ReadStayOpen($);
sub PrintTagList($@);
sub PrintErrors($$$);
sub Help();

$SIG{INT}  = 'SigInt';  # do cleanup on Ctrl-C
$SIG{CONT} = 'SigCont'; # (allows break-out of delays)
END {
    Cleanup();
}

# declare all static file-scope variables
my @commonArgs;     # arguments common to all commands
my @condition;      # conditional processing of files
my @csvFiles;       # list of files when reading with CSV option (in ExifTool Charset)
my @csvTags;        # order of tags for first file with CSV option (lower case)
my @delFiles;       # list of files to delete
my @dynamicFiles;   # list of -tagsFromFile files with dynamic names and -TAG<=FMT pairs
my @efile;          # files for writing list of error/fail/same file names
my @exclude;        # list of excluded tags
my (@echo3, @echo4);# stdout and stderr echo after processing is complete
my @files;          # list of files and directories to scan
my @moreArgs;       # more arguments to process after -stay_open -@
my @newValues;      # list of new tag values to set
my @requestTags;    # tags to request (for -p or -if option arguments)
my @srcFmt;         # source file name format strings
my @tags;           # list of tags to extract
my %appended;       # list of files appended to
my %countLink;      # count hard and symbolic links made
my %created;        # list of files we created
my %csvTags;        # lookup for all found tags with CSV option (lower case keys)
my %database;       # lookup for database information based on file name (in ExifTool Charset)
my %filterExt;      # lookup for filtered extensions
my %ignore;         # directory names to ignore
my $ignoreHidden;   # flag to ignore hidden files
my %preserveTime;   # preserved timestamps for files
my %printFmt;       # the contents of the print format file
my %setTags;        # hash of list references for tags to set from files
my %setTagsList;    # list of other tag lists for multiple -tagsFromFile from the same file
my %usedFileName;   # lookup for file names we already used in TestName feature
my %utf8FileName;   # lookup for file names that are UTF-8 encoded
my %warnedOnce;     # lookup for once-only warnings
my %wext;           # -W extensions to write
my $allGroup;       # show group name for all tags
my $altEnc;         # alternate character encoding if not UTF-8
my $argFormat;      # use exiftool argument-format output
my $binaryOutput;   # flag for binary output (undef or 1, or 0 for binary XML/PHP)
my $binaryStdout;   # flag set if we output binary to stdout
my $binSep;         # separator used for list items in binary output
my $binTerm;        # terminator used for binary output
my $comma;          # flag set if we need a comma in JSON output
my $count;          # count of files scanned when reading or deleting originals
my $countBad;       # count of files with errors
my $countBadCr;     # count files not created due to errors
my $countBadWr;     # count write errors
my $countCopyWr;    # count of files copied without being changed
my $countDir;       # count of directories scanned
my $countFailed;    # count files that failed condition
my $countGoodCr;    # count files created OK
my $countGoodWr;    # count files written OK
my $countNewDir;    # count of directories created
my $countSameWr;    # count files written OK but not changed
my $critical;       # flag for critical operations (disable CTRL-C)
my $csv;            # flag for CSV option (set to "CSV", or maybe "JSON" when writing)
my $csvAdd;         # flag to add CSV information to existing lists
my $csvDelim;       # delimiter for CSV files
my $csvSaveCount;   # save counter for last CSV file loaded
my $deleteOrig;     # 0=restore original files, 1=delete originals, 2=delete w/o asking
my $disableOutput;  # flag to disable normal output
my $doSetFileName;  # flag set if FileName may be written
my $doUnzip;        # flag to extract info from .gz and .bz2 files
my ($end,$endDir,%endDir);  # flags to end processing
my $escapeC;        # C-style escape
my $escapeHTML;     # flag to escape printed values for html
my $evalWarning;    # warning from eval
my $executeID;      # -execute ID number
my $failCondition;  # flag to fail -if condition
my $fastCondition;  # flag for fast -if condition
my $fileHeader;     # header to print to output file (or console, once)
my $fileTrailer;    # trailer for output file
my $filtered;       # flag indicating file was filtered by name
my $filterFlag;     # file filter flag (0x01=deny extensions, 0x02=allow extensions, 0x04=add ext)
my $fixLen;         # flag to fix description lengths when writing alternate languages
my $forcePrint;     # string to use for missing tag values (undef to not print them)
my $helped;         # flag to avoid printing help if no tags specified
my $html;           # flag for html-formatted output (2=html dump)
my $interrupted;    # flag set if CTRL-C is pressed during a critical process
my $isBinary;       # true if value is a SCALAR ref
my $isWriting;      # flag set if we are writing tags
my $joinLists;      # flag set to join list values into a single string
my $json;           # flag for JSON/PHP output format (1=JSON, 2=PHP)
my $langOpt;        # language option
my $listDir;        # treat a directory as a regular file
my $listItem;       # item number for extracting single item from a list
my $listSep;        # list item separator (', ' by default)
my $mt;             # main ExifTool object
my $multiFile;      # non-zero if we are scanning multiple files
my $noBinary;       # flag set to ignore binary tags
my $outFormat;      # -1=Canon format, 0=same-line, 1=tag names, 2=values only
my $outOpt;         # output file or directory name
my $overwriteOrig;  # flag to overwrite original file (1=overwrite, 2=in place)
my $pause;          # pause before returning
my $preserveTime;   # flag to preserve times of updated files (2=preserve FileCreateDate only)
my $progress;       # flag to calculate total files to process (0=calculate but don't display)
my $progressCount;  # count of files processed
my $progressMax;    # total number of files to process
my $progStr;        # progress message string
my $quiet;          # flag to disable printing of informational messages / warnings
my $rafStdin;       # File::RandomAccess for stdin (if necessary to rewind)
my $recurse;        # recurse into subdirectories (2=also hidden directories)
my $rtnVal;         # command return value (0=success)
my $rtnValPrev;     # previous command return value (0=success)
my $saveCount;      # count the number of times we will/did call SaveNewValues()
my $scanWritable;   # flag to process only writable file types
my $sectHeader;     # current section header for -p option
my $sectTrailer;    # section trailer for -p option
my $seqFileBase;    # sequential file number at start of directory
my $seqFileNum;     # sequential file number used for %C
my $setCharset;     # character set setting ('default' if not set and -csv -b used)
my $showGroup;      # number of group to show (may be zero or '')
my $showTagID;      # non-zero to show tag ID's
my $stayOpenBuff='';# buffer for -stay_open file
my $stayOpenFile;   # name of the current -stay_open argfile
my $structOpt;      # output structured XMP information (JSON and XML output only)
my $tabFormat;      # non-zero for tab output format
my $tagOut;         # flag for separate text output file for each tag
my $textOut;        # extension for text output file (or undef for no output)
my $textOverwrite;  # flag to overwrite existing text output file (2=append, 3=over+append)
my $tmpFile;        # temporary file to delete on exit
my $tmpText;        # temporary text file
my $validFile;      # flag indicating we processed a valid file
my $verbose;        # verbose setting
my $vout;           # verbose output file reference (\*STDOUT or \*STDERR)
my $windowTitle;    # title for console window
my $xml;            # flag for XML-formatted output

# flag to keep the input -@ argfile open:
# 0 = normal behaviour
# 1 = received "-stay_open true" and waiting for argfile to keep open
# 2 = currently reading from STAYOPEN argfile
# 3 = waiting for -@ to switch to a new STAYOPEN argfile
my $stayOpen = 0;

my $rtnValApp = 0;  # app return value (0=success)
my $curTitle = '';  # current window title

# lookup for O/S names which may use a backslash as a directory separator
# (ref File::Spec of PathTools-3.2701)
my %hasBackslash = ( MSWin32 => 1, os2 => 1, dos => 1, NetWare => 1, symbian => 1, cygwin => 1 );

# lookup for O/S names which use CR/LF newlines
my $isCRLF = { MSWin32 => 1, os2 => 1, dos => 1 }->{$^O};

# lookup for JSON characters that we escape specially
my %jsonChar = ( '"'=>'"', '\\'=>'\\', "\t"=>'t', "\n"=>'n', "\r"=>'r' );

# lookup for C-style escape sequences
my %escC = ( "\n" => '\n', "\r" => '\r', "\t" => '\t', '\\' => '\\\\');
my %unescC = ( a => "\a", b => "\b", f => "\f", n => "\n", r => "\r",
               t => "\t", 0 => "\0", '\\' => '\\' );

# options requiring additional arguments
# (used only to skip over these arguments when reading -stay_open ARGFILE)
# (arg is converted to lower case then tested again unless an entry was found with the same case)
my %optArgs = (
    '-tagsfromfile' => 1, '-addtagsfromfile' => 1, '-alltagsfromfile' => 1,
    '-@' => 1,
    '-api' => 1,
    '-c' => 1, '-coordformat' => 1,
    '-charset' => 0, # (optional arg; OK because arg cannot begin with "-")
    '-config' => 1,
    '-csvdelim' => 1,
    '-d' => 1, '-dateformat' => 1,
    '-D' => 0, # necessary to avoid matching lower-case equivalent
    '-echo' => 1, '-echo1' => 1, '-echo2' => 1, '-echo3' => 1, '-echo4' => 1,
    '-efile' => 1, '-efile1' => 1, '-efile2' => 1, '-efile3' => 1, '-efile4' => 1,
    '-efile!' => 1, '-efile1!' => 1, '-efile2!' => 1, '-efile3!' => 1, '-efile4!' => 1,
    '-ext' => 1, '--ext' => 1, '-ext+' => 1, '--ext+' => 1,
        '-extension' => 1, '--extension' => 1, '-extension+' => 1, '--extension+' => 1,
    '-fileorder' => 1, '-fileorder0' => 1, '-fileorder1' => 1, '-fileorder2' => 1,
        '-fileorder3' => 1, '-fileorder4' => 1, '-fileorder5' => 1,
    '-geotag' => 1,
    '-globaltimeshift' => 1,
    '-i' => 1, '-ignore' => 1,
    '-if' => 1, '-if0' => 1, '-if1' => 1, '-if2' => 1, '-if3' => 1, '-if4' => 1, '-if5' => 1,
    '-lang' => 0, # (optional arg; cannot begin with "-")
    '-listitem' => 1,
    '-o' => 1, '-out' => 1,
    '-p' => 1, '-printformat' => 1,
    '-P' => 0,
    '-password' => 1,
    '-require' => 1,
    '-sep' => 1, '-separator' => 1,
    '-srcfile' => 1,
    '-stay_open' => 1,
    '-use' => 1,
    '-userparam' => 1,
    '-w' => 1, '-w!' => 1, '-w+' => 1, '-w+!' => 1, '-w!+' => 1,
        '-textout' => 1, '-textout!' => 1, '-textout+' => 1, '-textout+!' => 1, '-textout!+' => 1,
         '-tagout' => 1,  '-tagout!' => 1,  '-tagout+' => 1,  '-tagout+!' => 1,  '-tagout!+' => 1,
    '-wext' => 1,
    '-wm' => 1, '-writemode' => 1,
    '-x' => 1, '-exclude' => 1,
    '-X' => 0,
);

# recommended packages and alternatives
my @recommends = qw(
    Archive::Zip
    Compress::Zlib
    Digest::MD5
    Digest::SHA
    IO::Compress::Bzip2
    POSIX::strptime
    Time::Local
    Unicode::LineBreak
    IO::Compress::RawDeflate
    IO::Uncompress::RawInflate
    Win32::API
    Win32::FindFile
    Win32API::File
);
my %altRecommends = (
   'POSIX::strptime' => 'Time::Piece', # (can use Time::Piece instead of POSIX::strptime)
);

my %unescapeChar = ( 't'=>"\t", 'n'=>"\n", 'r'=>"\r" );

# special subroutines used in -if condition
sub Image::ExifTool::EndDir() { return $endDir = 1 }
sub Image::ExifTool::End()    { return $end = 1 }

# exit routine
sub Exit {
    if ($pause) {
        if (eval { require Term::ReadKey }) {
            print STDERR "-- press any key --";
            Term::ReadKey::ReadMode('cbreak');
            Term::ReadKey::ReadKey(0);
            Term::ReadKey::ReadMode(0);
            print STDERR "\b \b" x 20;
        } else {
            print STDERR "-- press ENTER --\n";
            <STDIN>;
        }
    }
    exit shift;
}
# my warning and error routines (NEVER say "die"!)
sub Warn  {
    if ($quiet < 2 or $_[0] =~ /^Error/) {
        my $oldWarn = $SIG{'__WARN__'};
        delete $SIG{'__WARN__'};
        warn(@_);
        $SIG{'__WARN__'} = $oldWarn if defined $oldWarn;
    }
}
sub Error { Warn @_; $rtnVal = 1; }
sub WarnOnce($) {
    Warn(@_) and $warnedOnce{$_[0]} = 1 unless $warnedOnce{$_[0]};
}

# define signal handlers and cleanup routine
sub SigInt()  {
    $critical and $interrupted = 1, return;
    Cleanup();
    exit 1;
}
sub SigCont() { }
sub Cleanup() {
    $mt->Unlink($tmpFile) if defined $tmpFile;
    $mt->Unlink($tmpText) if defined $tmpText;
    undef $tmpFile;
    undef $tmpText;
    PreserveTime() if %preserveTime;
    SetWindowTitle('');
}

#------------------------------------------------------------------------------
# main script
#

# add arguments embedded in filename (Windows .exe version only)
if ($Image::ExifTool::exePath =~ /\(([^\\\/]+)\)(.exe|.pl)?$/i) {
    my $argstr = $1;
    # divide into separate quoted or whitespace-delineated arguments
    my (@args, $arg, $quote);
    while ($argstr =~ /(\s*)(\S+)/g) {
        $arg = $quote ? "$arg$1" : '';      # include quoted white space in arg
        my $a = $2;
        for (;;) {
            my $q = $quote || q{['"]};      # look for current (or any) quote
            $a =~ /(.*?)($q)/gs or last;    # get string up to quote
            $quote = $quote ? undef : $2;   # define next quote char for search
            $arg .= $1;                     # add to this argument
            $a = substr($a, pos($a));       # done parsing up to current position
        }
        $arg .= $a;                         # add unquoted part of string
        push @args, $arg unless $quote;     # save in argument list
    }
    unshift @ARGV, @args;   # add before other command-line arguments
}

# isolate arguments common to all commands
if (grep /^-common_args$/i, @ARGV) {
    my (@newArgs, $common);
    foreach (@ARGV) {
        if (/^-common_args$/i) {
            $common = 1;
        } elsif ($common) {
            push @commonArgs, $_;
        } else {
            push @newArgs, $_;
        }
    }
    @ARGV = @newArgs if $common;
}

#..............................................................................
# loop over sets of command-line arguments separated by "-execute"
Command: for (;;) {

if (@echo3) {
    my $str = join("\n", @echo3) . "\n";
    $str =~ s/\$\{status\}/$rtnVal/ig;
    print STDOUT $str;
}
if (@echo4) {
    my $str = join("\n", @echo4) . "\n";
    $str =~ s/\$\{status\}/$rtnVal/ig;
    print STDERR $str;
}

$rafStdin->Close() if $rafStdin;
undef $rafStdin;

# save our previous return codes
$rtnValPrev = $rtnVal;
$rtnValApp = $rtnVal if $rtnVal;

# exit Command loop now if we are all done processing commands
last unless @ARGV or not defined $rtnVal or $stayOpen >= 2 or @commonArgs;

# attempt to restore text mode for STDOUT if necessary
if ($binaryStdout) {
    binmode(STDOUT,':crlf') if $] >= 5.006 and $isCRLF;
    $binaryStdout = 0;
}

# flush console and print "{ready}" message if -stay_open is in effect
if ($stayOpen >= 2) {
    if ($quiet and not defined $executeID) {
        # flush output if possible
        eval { require IO::Handle } and STDERR->flush(), STDOUT->flush();
    } else {
        eval { require IO::Handle } and STDERR->flush();
        my $id = defined $executeID ? $executeID : '';
        my $save = $|;
        $| = 1;     # turn on output autoflush for stdout
        print "{ready$id}\n";
        $| = $save; # restore original autoflush setting
    }
}

# initialize necessary static file-scope variables
# (not done: @commonArgs, @moreArgs, $critical, $binaryStdout, $helped,
#  $interrupted, $mt, $pause, $rtnValApp, $rtnValPrev, $stayOpen, $stayOpenBuff, $stayOpenFile)
undef @condition;
undef @csvFiles;
undef @csvTags;
undef @delFiles;
undef @dynamicFiles;
undef @echo3;
undef @echo4;
undef @efile;
undef @exclude;
undef @files;
undef @newValues;
undef @srcFmt;
undef @tags;
undef %appended;
undef %countLink;
undef %created;
undef %csvTags;
undef %database;
undef %endDir;
undef %filterExt;
undef %ignore;
undef %printFmt;
undef %preserveTime;
undef %setTags;
undef %setTagsList;
undef %usedFileName;
undef %utf8FileName;
undef %warnedOnce;
undef %wext;
undef $allGroup;
undef $altEnc;
undef $argFormat;
undef $binaryOutput;
undef $binSep;
undef $binTerm;
undef $comma;
undef $csv;
undef $csvAdd;
undef $deleteOrig;
undef $disableOutput;
undef $doSetFileName;
undef $doUnzip;
undef $end;
undef $endDir;
undef $escapeHTML;
undef $escapeC;
undef $evalWarning;
undef $executeID;
undef $failCondition;
undef $fastCondition;
undef $fileHeader;
undef $filtered;
undef $fixLen;
undef $forcePrint;
undef $ignoreHidden;
undef $joinLists;
undef $langOpt;
undef $listItem;
undef $multiFile;
undef $noBinary;
undef $outOpt;
undef $preserveTime;
undef $progress;
undef $progressCount;
undef $progressMax;
undef $recurse;
undef $scanWritable;
undef $sectHeader;
undef $setCharset;
undef $showGroup;
undef $showTagID;
undef $structOpt;
undef $tagOut;
undef $textOut;
undef $textOverwrite;
undef $tmpFile;
undef $tmpText;
undef $validFile;
undef $verbose;
undef $windowTitle;

$count = 0;
$countBad = 0;
$countBadCr = 0;
$countBadWr = 0;
$countCopyWr = 0;
$countDir = 0;
$countFailed = 0;
$countGoodCr = 0;
$countGoodWr = 0;
$countNewDir = 0;
$countSameWr = 0;
$csvDelim = ',';
$csvSaveCount = 0;
$fileTrailer = '';
$filterFlag = 0;
$html = 0;
$isWriting = 0;
$json = 0;
$listSep = ', ';
$outFormat = 0;
$overwriteOrig = 0;
$progStr = '';
$quiet = 0;
$rtnVal = 0;
$saveCount = 0;
$sectTrailer = '';
$seqFileBase = 0;
$seqFileNum = 0;
$tabFormat = 0;
$vout = \*STDOUT;
$xml = 0;

# define local variables used only in this command loop
my @fileOrder;      # tags to use for ordering of input files
my $fileOrderFast;  # -fast level for -fileOrder option
my $addGeotime;     # automatically added geotime argument
my $doGlob;         # flag set to do filename wildcard expansion
my $endOfOpts;      # flag set if "--" option encountered
my $escapeXML;      # flag to escape printed values for xml
my $setTagsFile;    # filename for last TagsFromFile option
my $sortOpt;        # sort option is used
my $srcStdin;       # one of the source files is STDIN
my $useMWG;         # flag set if we are using any MWG tag

my ($argsLeft, @nextPass, $badCmd);
my $pass = 0;

# for Windows, use globbing for wildcard expansion if available - MK/20061010
if ($^O eq 'MSWin32' and eval { require File::Glob }) {
    # override the core glob forcing case insensitivity
    import File::Glob qw(:globally :nocase);
    $doGlob = 1;
}

$mt = new Image::ExifTool;      # create ExifTool object

# don't extract duplicates by default unless set by UserDefined::Options
$mt->Options(Duplicates => 0) unless %Image::ExifTool::UserDefined::Options
    and defined $Image::ExifTool::UserDefined::Options{Duplicates};

# default is to join lists if the List option was set to zero in the config file
$joinLists = 1 if defined $mt->Options('List') and not $mt->Options('List');

# preserve FileCreateDate if possible
if (not $preserveTime and $^O eq 'MSWin32') {
    $preserveTime = 2 if  eval { require Win32::API } and eval { require Win32API::File };
}

# parse command-line options in 2 passes...
# pass 1: set all of our ExifTool options
# pass 2: print all of our help and informational output (-list, -ver, etc)
for (;;) {

  # execute the command now if no more arguments or -execute is used
  if (not @ARGV or ($ARGV[0] =~ /^(-|\xe2\x88\x92)execute(\d+)?$/i and not $endOfOpts)) {
    if (@ARGV) {
        $executeID = $2;        # save -execute number for "{ready}" response
        $helped = 1;            # don't show help if we used -execute
        $badCmd and shift, $rtnVal=1, next Command;
    } elsif ($stayOpen >= 2) {
        ReadStayOpen(\@ARGV);   # read more arguments from -stay_open file
        next;
    } elsif ($badCmd) {
        undef @commonArgs;      # all done.  Flush common arguments
        $rtnVal = 1;
        next Command;
    }
    if ($pass == 0) {
        # insert common arguments now if not done already
        if (@commonArgs and not defined $argsLeft) {
            # count the number of arguments remaining for subsequent commands
            $argsLeft = scalar(@ARGV) + scalar(@moreArgs);
            unshift @ARGV, @commonArgs;
            # all done with commonArgs if this is the end of the command
            undef @commonArgs unless $argsLeft;
            next;
        }
        # check if we have more arguments now than we did before we processed
        # the common arguments.  If so, then we have an infinite processing loop
        if (defined $argsLeft and $argsLeft < scalar(@ARGV) + scalar(@moreArgs)) {
            Warn "Ignoring -common_args from $ARGV[0] onwards to avoid infinite recursion\n";
            while ($argsLeft < scalar(@ARGV) + scalar(@moreArgs)) {
                @ARGV and shift(@ARGV), next;
                shift @moreArgs;
            }
        }
        # require MWG module if used in any argument
        # (note: doesn't cover the -p option because these tags will be parsed on the 2nd pass)
        $useMWG = 1 if not $useMWG and grep /^mwg:/i, @tags, @requestTags;
        if ($useMWG) {
            require Image::ExifTool::MWG;
            Image::ExifTool::MWG::Load();
        }
        # update necessary variables for 2nd pass
        if (defined $forcePrint) {
            unless (defined $mt->Options('MissingTagValue')) {
                $mt->Options(MissingTagValue => '-');
            }
            $forcePrint = $mt->Options('MissingTagValue');
        }
    }
    if (@nextPass) {
        # process arguments which were deferred to the next pass
        unshift @ARGV, @nextPass;
        undef @nextPass;
        undef $endOfOpts;
        ++$pass;
        next;
    }
    @ARGV and shift;    # remove -execute from argument list
    last;               # process the command now
  }
  $_ = shift;
  next if $badCmd;      # flush remaining arguments if aborting this command

  # allow funny dashes (nroff dash bug for cut-n-paste from pod)
  if (not $endOfOpts and s/^(-|\xe2\x88\x92)//) {
    s/^\xe2\x88\x92/-/;         # translate double-dash too
    if ($_ eq '-') {
        $pass or push @nextPass, '--';
        $endOfOpts = 1;
        next;
    }
    my $a = lc $_;
    if (/^list([wfrdx]|wf|g(\d*))?$/i) {
        $pass or push @nextPass, "-$_";
        my $type = lc($1 || '');
        if (not $type or $type eq 'w' or $type eq 'x') {
            my $group;
            if ($ARGV[0] and $ARGV[0] =~ /^(-|\xe2\x88\x92)(.+):(all|\*)$/i) {
                if ($pass == 0) {
                    $useMWG = 1 if lc($2) eq 'mwg';
                    push @nextPass, shift;
                    next;
                }
                $group = $2;
                shift;
                $group =~ /IFD/i and Warn("Can't list tags for specific IFD\n"), next;
                $group =~ /^(all|\*)$/ and undef $group;
            } else {
                $pass or next;
            }
            $helped = 1;
            if ($type eq 'x') {
                require Image::ExifTool::TagInfoXML;
                my %opts;
                $opts{Flags} = 1 if defined $forcePrint;
                $opts{NoDesc} = 1 if $outFormat > 0;
                $opts{Lang} = $langOpt;
                Image::ExifTool::TagInfoXML::Write(undef, $group, %opts);
                next;
            }
            my $wr = ($type eq 'w');
            my $msg = ($wr ? 'Writable' : 'Available') . ($group ? " $group" : '') . ' tags';
            PrintTagList($msg, $wr ? GetWritableTags($group) : GetAllTags($group));
            # also print shortcuts if listing all tags
            next if $group or $wr;
            my @tagList = GetShortcuts();
            PrintTagList('Command-line shortcuts', @tagList) if @tagList;
            next;
        }
        $pass or next;
        $helped = 1;
        if ($type eq 'wf') {
            my @wf;
            CanWrite($_) and push @wf, $_ foreach GetFileType();
            PrintTagList('Writable file extensions', @wf);
        } elsif ($type eq 'f') {
            PrintTagList('Supported file extensions', GetFileType());
        } elsif ($type eq 'r') {
            PrintTagList('Recognized file extensions', GetFileType(undef, 0));
        } elsif ($type eq 'd') {
            PrintTagList('Deletable groups', GetDeleteGroups());
        } else { # 'g(\d*)'
            # list all groups in specified family
            my $family = $2 || 0;
            PrintTagList("Groups in family $family", $mt->GetAllGroups($family));
        }
        next;
    }
    if ($a eq 'ver') {
        $pass or push(@nextPass,'-ver'), next;
        my $libVer = $Image::ExifTool::VERSION;
        my $str = $libVer eq $version ? '' : " [Warning: Library version is $libVer]";
        if ($verbose) {
            print "ExifTool version $version$str$Image::ExifTool::RELEASE\n";
            printf "Perl version %s%s\n", $], (defined ${^UNICODE} ? " (-C${^UNICODE})" : '');
            print "Platform: $^O\n";
            print "Optional libraries:\n";
            foreach (@recommends) {
                next if /^Win32/ and $^O ne 'MSWin32';
                my $ver = eval "require $_ and \$${_}::VERSION";
                my $alt = $altRecommends{$_};
                # check for alternative if primary not available
                $ver = eval "require $alt and \$${alt}::VERSION" and $_ = $alt if not $ver and $alt;
                printf "  %-28s %s\n", $_, $ver || '(not installed)';
            }
            if ($verbose > 1) {
                print "Include directories:\n";
                print "  $_\n" foreach @INC;
            }
        } else {
            print "$version$str$Image::ExifTool::RELEASE\n";
        }
        $helped = 1;
        next;
    }
    if (/^(all|add)?tagsfromfile(=.*)?$/i) {
        $setTagsFile = $2 ? substr($2,1) : (@ARGV ? shift : '');
        if ($setTagsFile eq '') {
            Error("File must be specified for -tagsFromFile option\n");
            $badCmd = 1;
            next;
        }
        # create necessary lists, etc for this new -tagsFromFile file
        AddSetTagsFile($setTagsFile, { Replace => ($1 and lc($1) eq 'add') ? 0 : 1 } );
        next;
    }
    if ($a eq '@') {
        my $argFile = shift or Error("Expecting filename for -\@ option\n"), $badCmd=1, next;
        # switch to new ARGFILE if using chained -stay_open options
        if ($stayOpen == 1) {
            # defer remaining arguments until we close this argfile
            @moreArgs = @ARGV;
            undef @ARGV;
        } elsif ($stayOpen == 3) {
            if ($stayOpenFile and $stayOpenFile ne '-' and $argFile eq $stayOpenFile) {
                # don't allow user to switch to the same -stay_open argfile
                # because it will result in endless recursion
                $stayOpen = 2;
                Warn "Ignoring request to switch to the same -stay_open ARGFILE ($argFile)\n";
                next;
            }
            close STAYOPEN;
            $stayOpen = 1;  # switch to this -stay_open file
        }
        my $fp = ($stayOpen == 1 ? \*STAYOPEN : \*ARGFILE);
        unless ($mt->Open($fp, $argFile)) {
            unless ($argFile !~ /^\// and $mt->Open($fp, "$exeDir/$argFile")) {
                Error "Error opening arg file $argFile\n";
                $badCmd = 1;
                next
            }
        }
        if ($stayOpen == 1) {
            $stayOpenFile = $argFile;   # remember the name of the file we have open
            $stayOpenBuff = '';         # initialize buffer for reading this file
            $stayOpen = 2;
            $helped = 1;
            ReadStayOpen(\@ARGV);
            next;
        }
        my (@newArgs, $didBOM);
        foreach (<ARGFILE>) {
            # filter Byte Order Mark if it exists from start of UTF-8 text file
            unless ($didBOM) {
                s/^\xef\xbb\xbf//;
                $didBOM = 1;
            }
            $_ = FilterArgfileLine($_);
            push @newArgs, $_ if defined $_;
        }
        close ARGFILE;
        unshift @ARGV, @newArgs;
        next;
    }
    /^(-?)(a|duplicates)$/i and $mt->Options(Duplicates => ($1 ? 0 : 1)), next;
    if ($a eq 'api') {
        my $opt = shift;
        defined $opt or Error("Expected OPT[=VAL] argument for -api option\n"), $badCmd=1, next;
        my $val = ($opt =~ s/=(.*)//s) ? $1 : 1;
        # empty string means an undefined value unless ^= is used
        $val = undef unless $opt =~ s/\^$// or length $val;
        $mt->Options($opt => $val);
        next;
    }
    /^arg(s|format)$/i and $argFormat = 1, next;
    if (/^(-?)b(inary)?$/i) {
        ($binaryOutput, $noBinary) = $1 ? (undef, 1) : (1, undef);
        $mt->Options(Binary => $binaryOutput, NoPDFList => $binaryOutput);
        next;
    }
    if (/^c(oordFormat)?$/i) {
        my $fmt = shift;
        $fmt or Error("Expecting coordinate format for -c option\n"), $badCmd=1, next;
        $mt->Options('CoordFormat', $fmt);
        next;
    }
    if ($a eq 'charset') {
        my $charset = (@ARGV and $ARGV[0] !~ /^(-|\xe2\x88\x92)/) ? shift : undef;
        if (not $charset) {
            $pass or push(@nextPass, '-charset'), next;
            my %charsets;
            $charsets{$_} = 1 foreach values %Image::ExifTool::charsetName;
            PrintTagList('Available character sets', sort keys %charsets);
            $helped = 1;
        } elsif ($charset !~ s/^(\w+)=// or lc($1) eq 'exiftool') {
            {
                local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
                undef $evalWarning;
                $mt->Options(Charset => $charset);
            }
            if ($evalWarning) {
                warn $evalWarning;
            } else {
                $setCharset = $mt->Options('Charset');
            }
        } else {
            # set internal encoding of specified metadata type
            my $type = { id3 => 'ID3', iptc => 'IPTC', exif => 'EXIF', filename => 'FileName',
                         photoshop => 'Photoshop', quicktime => 'QuickTime', riff=>'RIFF' }->{lc $1};
            $type or Warn("Unknown type for -charset option: $1\n"), next;
            $mt->Options("Charset$type" => $charset);
        }
        next;
    }
    /^config$/i and Warn("Ignored -config option (not first on command line)\n"), shift, next;
    if (/^csv(\+?=.*)?$/i) {
        my $csvFile = $1;
        # must process on 2nd pass so -f and -charset options are available
        unless ($pass) {
            push @nextPass, "-$_";
            if ($csvFile) {
                push @newValues, { SaveCount => ++$saveCount }; # marker to save new values now
                $csvSaveCount = $saveCount;
            }
            next;
        }
        if ($csvFile) {
            $csvFile =~ s/^(\+?=)//;
            $csvAdd = 2 if $1 eq '+=';
            $vout = \*STDERR if $srcStdin;
            $verbose and print $vout "Reading CSV file $csvFile\n";
            my $msg;
            if ($mt->Open(\*CSVFILE, $csvFile)) {
                binmode CSVFILE;
                require Image::ExifTool::Import;
                $msg = Image::ExifTool::Import::ReadCSV(\*CSVFILE, \%database, $forcePrint, $csvDelim);
                close(CSVFILE);
            } else {
                $msg = "Error opening CSV file '${csvFile}'";
            }
            $msg and Warn("$msg\n");
            $isWriting = 1;
        }
        $csv = 'CSV';
        next;
    }
    if (/^csvdelim$/i) {
        $csvDelim = shift;
        defined $csvDelim or Error("Expecting argument for -csvDelim option\n"), $badCmd=1, next;
        $csvDelim =~ /"/ and Error("CSV delimiter can not contain a double quote\n"), $badCmd=1, next;
        my %unescape = ( 't'=>"\t", 'n'=>"\n", 'r'=>"\r", '\\' => '\\' );
        $csvDelim =~ s/\\(.)/$unescape{$1}||"\\$1"/sge;
        $mt->Options(CSVDelim => $csvDelim);
        next;
    }
    if (/^d$/ or $a eq 'dateformat') {
        my $fmt = shift;
        $fmt or Error("Expecting date format for -d option\n"), $badCmd=1, next;
        $mt->Options('DateFormat', $fmt);
        next;
    }
    (/^D$/ or $a eq 'decimal') and $showTagID = 'D', next;
    /^delete_original(!?)$/i and $deleteOrig = ($1 ? 2 : 1), next;
    /^list_dir$/i and $listDir = 1, next;
    (/^e$/ or $a eq '-composite') and $mt->Options(Composite => 0), next;
    (/^-e$/ or $a eq 'composite') and $mt->Options(Composite => 1), next;
    (/^E$/ or $a eq 'escapehtml') and require Image::ExifTool::HTML and $escapeHTML = 1, next;
    ($a eq 'ec' or $a eq 'escapec') and $escapeC = 1, next;
    ($a eq 'ex' or $a eq 'escapexml') and $escapeXML = 1, next;
    if (/^echo(\d)?$/i) {
        my $n = $1 || 1;
        my $arg = shift;
        next unless defined $arg;
        $n > 4 and Warn("Invalid -echo number\n"), next;
        if ($n > 2) {
            $n == 3 ? push(@echo3, $arg) : push(@echo4, $arg);
        } else {
            print {$n==2 ? \*STDERR : \*STDOUT} $arg, "\n";
        }
        $helped = 1;
        next;
    }
    if (/^(ee|extractembedded)(\d*)$/i) {
        $mt->Options(ExtractEmbedded => $2 || 1);
        $mt->Options(Duplicates => 1);
        next;
    }
    if (/^efile(\d)?(!)?$/i) {
        my $arg = shift;
        defined $arg or Error("Expecting file name for -$_ option\n"), $badCmd=1, next;
        $efile[0] = $arg if not $1 or $1 & 0x01;
        $efile[1] = $arg if $1 and $1 & 0x02;
        $efile[2] = $arg if $1 and $1 & 0x04;
        unlink $arg if $2;
        next;
    }
    # (-execute handled at top of loop)
    if (/^-?ext(ension)?(\+)?$/i) {
        my $ext = shift;
        defined $ext or Error("Expecting extension for -ext option\n"), $badCmd=1, next;
        my $flag = /^-/ ? 0 : ($2 ? 2 : 1);
        $filterFlag |= (0x01 << $flag);
        $ext =~ s/^\.//;    # remove leading '.' if it exists
        $filterExt{uc($ext)} = $flag ? 1 : 0;
        next;
    }
    if (/^f$/ or $a eq 'forceprint') {
        $forcePrint = 1;
        next;
    }
    if (/^F([-+]?\d*)$/ or /^fixbase([-+]?\d*)$/i) {
        $mt->Options(FixBase => $1);
        next;
    }
    if (/^fast(\d*)$/i) {
        $mt->Options(FastScan => (length $1 ? $1 : 1));
        next;
    }
    if (/^fileorder(\d*)$/i) {
        push @fileOrder, shift if @ARGV;
        my $num = $1 || 0;
        $fileOrderFast = $num if not defined $fileOrderFast or $fileOrderFast > $num;
        next;
    }
    $a eq 'globaltimeshift' and $mt->Options(GlobalTimeShift => shift), next;
    if (/^(g)(roupHeadings|roupNames)?([\d:]*)$/i) {
        $showGroup = $3 || 0;
        $allGroup = ($2 ? lc($2) eq 'roupnames' : $1 eq 'G');
        $mt->Options(SavePath => 1) if $showGroup =~ /\b5\b/;
        $mt->Options(SaveFormat => 1) if $showGroup =~ /\b6\b/;
        next;
    }
    if ($a eq 'geotag') {
        my $trkfile = shift;
        unless ($pass) {
            # defer to next pass so the filename charset is available
            push @nextPass, '-geotag', $trkfile;
            next;
        }
        $trkfile or Error("Expecting file name for -geotag option\n"), $badCmd=1, next;
        # allow wildcards in filename
        if ($trkfile =~ /[*?]/) {
            # CORE::glob() splits on white space, so use File::Glob if possible
            my @trks;
            if ($^O eq 'MSWin32' and eval { require Win32::FindFile }) {
                # ("-charset filename=UTF8" must be set for this to work with Unicode file names)
                @trks = FindFileWindows($mt, $trkfile);
            } elsif (eval { require File::Glob }) {
                @trks = File::Glob::bsd_glob($trkfile);
            } else {
                @trks = glob($trkfile);
            }
            @trks or Error("No matching file found for -geotag option\n"), $badCmd=1, next;
            push @newValues, 'geotag='.shift(@trks) while @trks > 1;
            $trkfile = pop(@trks);
        }
        $_ = "geotag=$trkfile";
        # (fall through!)
    }
    if (/^h$/ or $a eq 'htmlformat') {
        require Image::ExifTool::HTML;
        $html = $escapeHTML = 1;
        $json = $xml = 0;
        next;
    }
    (/^H$/ or $a eq 'hex') and $showTagID = 'H', next;
    if (/^htmldump([-+]?\d+)?$/i) {
        $verbose = ($verbose || 0) + 1;
        $html = 2;
        $mt->Options(HtmlDumpBase => $1) if defined $1;
        next;
    }
    if (/^i(gnore)?$/i) {
        my $dir = shift;
        defined $dir or Error("Expecting directory name for -i option\n"), $badCmd=1, next;
        $ignore{$dir} = 1;
        $dir eq 'HIDDEN' and $ignoreHidden = 1;
        next;
    }
    if (/^if(\d*)$/i) {
        my $cond = shift;
        $fastCondition = $1 if length $1;
        defined $cond or Error("Expecting expression for -if option\n"), $badCmd=1, next;
        # prevent processing file unnecessarily for simple case of failed '$ok' or 'not $ok'
        $cond =~ /^\s*(not\s*)\$ok\s*$/i and ($1 xor $rtnValPrev) and $failCondition=1;
        # add to list of requested tags
        push @requestTags, $cond =~ /\$\{?((?:[-\w]+:)*[-\w?*]+)/g;
        push @condition, $cond;
        next;
    }
    if (/^j(son)?(\+?=.*)?$/i) {
        if ($2) {
            # must process on 2nd pass because we need -f and -charset options
            unless ($pass) {
                push @nextPass, "-$_";
                push @newValues, { SaveCount => ++$saveCount }; # marker to save new values now
                $csvSaveCount = $saveCount;
                next;
            }
            my $jsonFile = $2;
            $jsonFile =~ s/^(\+?=)//;
            $csvAdd = 2 if $1 eq '+=';
            $vout = \*STDERR if $srcStdin;
            $verbose and print $vout "Reading JSON file $jsonFile\n";
            my $chset = $mt->Options('Charset');
            my $msg;
            if ($mt->Open(\*JSONFILE, $jsonFile)) {
                binmode JSONFILE;
                require Image::ExifTool::Import;
                $msg = Image::ExifTool::Import::ReadJSON(\*JSONFILE, \%database, $forcePrint, $chset);
                close(JSONFILE);
            } else {
                $msg = "Error opening JSON file '${jsonFile}'";
            }
            $msg and Warn("$msg\n");
            $isWriting = 1;
            $csv = 'JSON';
        } else {
            $json = 1;
            $html = $xml = 0;
            $mt->Options(Duplicates => 1);
            require Image::ExifTool::XMP;   # for FixUTF8()
        }
        next;
    }
    /^(k|pause)$/i and $pause = 1, next;
    (/^l$/ or $a eq 'long') and --$outFormat, next;
    (/^L$/ or $a eq 'latin') and $mt->Options(Charset => 'Latin'), next;
    if ($a eq 'lang') {
        $langOpt = (@ARGV and $ARGV[0] !~ /^(-|\xe2\x88\x92)/) ? shift : undef;
        if ($langOpt) {
            # make lower case and use underline as a separator (eg. 'en_ca')
            $langOpt =~ tr/-A-Z/_a-z/;
            $mt->Options(Lang => $langOpt);
            next if $langOpt eq $mt->Options('Lang');
        } else {
            $pass or push(@nextPass, '-lang'), next;
        }
        my $langs = "Available languages:\n";
        $langs .= "  $_ - $Image::ExifTool::langName{$_}\n" foreach @Image::ExifTool::langs;
        $langs =~ tr/_/-/;  # display dashes instead of underlines in language codes
        $langs = Image::ExifTool::HTML::EscapeHTML($langs) if $escapeHTML;
        $langs = $mt->Decode($langs, 'UTF8');
        $langOpt and Error("Invalid or unsupported language '${langOpt}'.\n$langs"), $badCmd=1, next;
        print $langs;
        $helped = 1;
        next;
    }
    if ($a eq 'listitem') {
        my $li = shift;
        defined $li and Image::ExifTool::IsInt($li) or Warn("Expecting integer for -listItem option\n"), next;
        $mt->Options(ListItem => $li);
        $listItem = $li;
        next;
    }
    /^(m|ignoreminorerrors)$/i and $mt->Options(IgnoreMinorErrors => 1), next;
    /^(n|-printconv)$/i and $mt->Options(PrintConv => 0), next;
    /^(-n|printconv)$/i and $mt->Options(PrintConv => 1), next;
    $a eq 'nop' and $helped=1, next; # (undocumented) no operation, added in 11.25
    if (/^o(ut)?$/i) {
        $outOpt = shift;
        defined $outOpt or Error("Expected output file or directory name for -o option\n"), $badCmd=1, next;
        CleanFilename($outOpt);
        # verbose messages go to STDERR of output is to console
        $vout = \*STDERR if $vout =~ /^-(\.\w+)?$/;
        next;
    }
    /^overwrite_original$/i and $overwriteOrig = 1, next;
    /^overwrite_original_in_place$/i and $overwriteOrig = 2, next;
    if (/^p$/ or $a eq 'printformat') {
        my $fmt = shift;
        if ($pass) {
            LoadPrintFormat($fmt);
            # load MWG module now if necessary
            if (not $useMWG and grep /^mwg:/i, @requestTags) {
                $useMWG = 1;
                require Image::ExifTool::MWG;
                Image::ExifTool::MWG::Load();
            }
        } else {
            # defer to next pass so the filename charset is available
            push @nextPass, '-p', $fmt;
        }
        next;
    }
    (/^P$/ or $a eq 'preserve') and $preserveTime = 1, next;
    /^password$/i and $mt->Options(Password => shift), next;
    if (/^progress(:.*)?$/i) {
        if ($1) {
            $windowTitle = substr $1, 1;
            $windowTitle = 'ExifTool %p%%' unless length $windowTitle;
            $windowTitle =~ /%\d*[bpr]/ and $progress = 0 unless defined $progress;
        } else {
            $progress = 1;
            $verbose = 0 unless defined $verbose;
        }
        $progressCount = 0;
        next;
    }
    /^q(uiet)?$/i and ++$quiet, next;
    /^r(ecurse)?(\.?)$/i and $recurse = ($2 ? 2 : 1), next;
    if ($a eq 'require') { # (undocumented) added in version 8.65
        my $ver = shift;
        unless (defined $ver and Image::ExifTool::IsFloat($ver)) {
            Error("Expecting version number for -require option\n");
            $badCmd = 1;
            next;
        }
        unless ($Image::ExifTool::VERSION >= $ver) {
            Error("Requires ExifTool version $ver or later\n");
            $badCmd = 1;
        }
        next;
    }
    /^restore_original$/i and $deleteOrig = 0, next;
    (/^S$/ or $a eq 'veryshort') and $outFormat+=2, next;
    /^s(hort)?(\d*)$/i and $outFormat = $2 eq '' ? $outFormat + 1 : $2, next;
    /^scanforxmp$/i and $mt->Options(ScanForXMP => 1), next;
    if (/^sep(arator)?$/i) {
        my $sep = $listSep = shift;
        defined $listSep or Error("Expecting list item separator for -sep option\n"), $badCmd=1, next;
        $sep =~ s/\\(.)/$unescapeChar{$1}||$1/sge;   # translate escape sequences
        (defined $binSep ? $binTerm : $binSep) = $sep;
        $mt->Options(ListSep => $listSep);
        $joinLists = 1;
        # also split when writing values
        my $listSplit = quotemeta $listSep;
        # a space in the string matches zero or more whitespace characters
        $listSplit =~ s/(\\ )+/\\s\*/g;
        # but a single space alone matches one or more whitespace characters
        $listSplit = '\\s+' if $listSplit eq '\\s*';
        $mt->Options(ListSplit => $listSplit);
        next;
    }
    /^(-)?sort$/i and $sortOpt = $1 ? 0 : 1, next;
    if ($a eq 'srcfile') {
        @ARGV or Warn("Expecting FMT for -srcfile option\n"), next;
        push @srcFmt, shift;
        next;
    }
    if ($a eq 'stay_open') {
        my $arg = shift;
        defined $arg or Warn("Expecting argument for -stay_open option\n"), next;
        if ($arg =~ /^(1|true)$/i) {
            if (not $stayOpen) {
                $stayOpen = 1;
            } elsif ($stayOpen == 2) {
                $stayOpen = 3;  # chained -stay_open options
            } else {
                Warn "-stay_open already active\n";
            }
        } elsif ($arg =~ /^(0|false)$/i) {
            if ($stayOpen >= 2) {
                # close -stay_open argfile and process arguments up to this point
                close STAYOPEN;
                push @ARGV, @moreArgs;
                undef @moreArgs;
            } elsif (not $stayOpen) {
                Warn("-stay_open wasn't active\n");
            }
            $stayOpen = 0;
        } else {
            Warn "Invalid argument for -stay_open\n";
        }
        next;
    }
    if (/^(-)?struct$/i) {
        $mt->Options(Struct => $1 ? 0 : 1);
        next;
    }
    /^t(ab)?$/  and $tabFormat = 1, next;
    if (/^T$/ or $a eq 'table') {
        $tabFormat = $forcePrint = 1; $outFormat+=2; ++$quiet;
        next;
    }
    if (/^(u)(nknown(2)?)?$/i) {
        my $inc = ($3 or (not $2 and $1 eq 'U')) ? 2 : 1;
        $mt->Options(Unknown => $mt->Options('Unknown') + $inc);
        next;
    }
    if ($a eq 'use') {
        my $module = shift;
        $module or Error("Expecting module name for -use option\n"), $badCmd=1, next;
        lc $module eq 'mwg' and $useMWG = 1, next;
        $module =~ /[^\w:]/ and Error("Invalid module name: $module\n"), $badCmd=1, next;
        local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
        unless (eval "require Image::ExifTool::$module" or
                eval "require $module" or
                eval "require '${module}'")
        {
            Error("Error using module $module\n");
            $badCmd = 1;
        }
        next;
    }
    if ($a eq 'userparam') {
        my $opt = shift;
        defined $opt or Error("Expected parameter for -userParam option\n"), $badCmd=1, next;
        $opt =~ /=/ or $opt .= '=1';
        $mt->Options(UserParam => $opt);
        next;
    }
    if (/^v(erbose)?(\d*)$/i) {
        $verbose = ($2 eq '') ? ($verbose || 0) + 1 : $2;
        next;
    }
    if (/^(w|textout|tagout)([!+]*)$/i) {
        $textOut = shift || Warn("Expecting output extension for -$_ option\n");
        my ($t1, $t2) = ($1, $2);
        $textOverwrite = 0;
        $textOverwrite += 1 if $t2 =~ /!/;  # overwrite
        $textOverwrite += 2 if $t2 =~ /\+/; # append
        if ($t1 ne 'W' and lc($t1) ne 'tagout') {
            undef $tagOut;
        } elsif ($textOverwrite >= 2 and $textOut !~ /%[-+]?\d*[.:]?\d*[lu]?[tgs]/) {
            $tagOut = 0; # append tags to one file
        } else {
            $tagOut = 1; # separate file for each tag
        }
        next;
    }
    if (/^(-?)(wext|tagoutext)$/i) {
        my $ext = shift;
        defined $ext or Error("Expecting extension for -wext option\n"), $badCmd=1, next;
        my $flag = 1;
        $1 and $wext{'*'} = 1, $flag = -1;
        $ext =~ s/^\.//;
        $wext{lc $ext} = $flag;
        next;
    }
    if ($a eq 'wm' or $a eq 'writemode') {
        my $wm = shift;
        defined $wm or Error("Expecting argument for -$_ option\n"), $badCmd=1, next;
        $wm =~ /^[wcg]*$/i or Error("Invalid argument for -$_ option\n"), $badCmd=1, next;
        $mt->Options(WriteMode => $wm);
        next;
    }
    if (/^x$/ or $a eq 'exclude') {
        my $tag = shift;
        defined $tag or Error("Expecting tag name for -x option\n"), $badCmd=1, next;
        $tag =~ s/\ball\b/\*/ig;    # replace 'all' with '*' in tag names
        if ($setTagsFile) {
            push @{$setTags{$setTagsFile}}, "-$tag";
        } else {
            push @exclude, $tag;
        }
        next;
    }
    (/^X$/ or $a eq 'xmlformat') and $xml = 1, $html = $json = 0, $mt->Options(Duplicates => 1), next;
    if (/^php$/i) {
        $json = 2;
        $html = $xml = 0;
        $mt->Options(Duplicates => 1);
        next;
    }
    if (/^z(ip)?$/i) {
        $doUnzip = 1;
        $mt->Options(Compress => 1, XMPShorthand => 1);
        $mt->Options(Compact => 1) unless $mt->Options('Compact');
        next;
    }
    $_ eq '' and push(@files, '-'), $srcStdin = 1, next;   # read STDIN
    length $_ eq 1 and $_ ne '*' and Error("Unknown option -$_\n"), $badCmd=1, next;
    if (/^[^<]+(<?)=(.*)/s) {
        my $val = $2;
        if ($1 and length($val) and ($val eq '@' or not defined FilenameSPrintf($val))) {
            # save count of new values before a dynamic value
            push @newValues, { SaveCount => ++$saveCount };
        }
        push @newValues, $_;
        if (/^mwg:/i) {
            $useMWG = 1;
        } elsif (/^([-\w]+:)*(filename|directory|testname)\b/i) {
            $doSetFileName = 1;
        } elsif (/^([-\w]+:)*(geotag|geotime|geosync)\b/i) {
            if (lc $2 eq 'geotime') {
                $addGeotime = '';
            } else {
                # add geotag/geosync commands first
                unshift @newValues, pop @newValues;
                if (lc $2 eq 'geotag' and (not defined $addGeotime or $addGeotime) and length $val) {
                    $addGeotime = ($1 || '') . 'Geotime<DateTimeOriginal#';
                }
            }
        }
    } else {
        # assume '-tagsFromFile @' if tags are being redirected
        # and -tagsFromFile hasn't already been specified
        AddSetTagsFile($setTagsFile = '@') if not $setTagsFile and /(<|>)/;
        if ($setTagsFile) {
            push @{$setTags{$setTagsFile}}, $_;
            if (/>/) {
                $useMWG = 1 if /^(.*>\s*)?mwg:/si;
                if (/\b(filename|directory|testname)#?$/i) {
                    $doSetFileName = 1;
                } elsif (/\bgeotime#?$/i) {
                    $addGeotime = '';
                }
            } else {
                $useMWG = 1 if /^([^<]+<\s*(.*\$\{?)?)?mwg:/si;
                if (/^([-\w]+:)*(filename|directory|testname)\b/i) {
                    $doSetFileName = 1;
                } elsif (/^([-\w]+:)*geotime\b/i) {
                    $addGeotime = '';
                }
            }
        } else {
            my $lst = s/^-// ? \@exclude : \@tags;
            unless (/^([-\w*]+:)*([-\w*?]+)#?$/) {
                Warn(qq(Invalid TAG name: "$_"\n));
            }
            push @$lst, $_; # (push everything for backward compatibility)
        }
    }
  } else {
    unless ($pass) {
        # defer to next pass so the filename charset is available
        push @nextPass, $_;
        next;
    }
    if ($doGlob and /[*?]/) {
        if ($^O eq 'MSWin32' and eval { require Win32::FindFile }) {
            push @files, FindFileWindows($mt, $_);
        } else {
            # glob each filespec if necessary - MK/20061010
            push @files, File::Glob::bsd_glob($_);
        }
        $doGlob = 2;
    } else {
        push @files, $_;
        $srcStdin = 1 if $_ eq '-';
    }
  }
}

# set "OK" UserParam based on result of last command
$mt->Options(UserParam => 'OK=' . (not $rtnValPrev));

# set verbose output to STDERR if output could be to console
$vout = \*STDERR if $srcStdin and ($isWriting or @newValues);
$mt->Options(TextOut => $vout) if $vout eq \*STDERR;

# change default EXIF string encoding if MWG used
if ($useMWG and not defined $mt->Options('CharsetEXIF')) {
    $mt->Options(CharsetEXIF => 'UTF8');
}

# print help
unless ((@tags and not $outOpt) or @files or @newValues) {
    if ($doGlob and $doGlob == 2) {
        Warn "No matching files\n";
        $rtnVal = 1;
        next;
    }
    if ($outOpt) {
        Warn "Nothing to write\n";
        $rtnVal = 1;
        next;
    }
    Help() unless $helped;
    next;
}

# do sanity check on -delete_original and -restore_original
if (defined $deleteOrig and (@newValues or @tags)) {
    if (not @newValues) {
        my $verb = $deleteOrig ? 'deleting' : 'restoring from';
        Warn "Can't specify tags when $verb originals\n";
    } elsif ($deleteOrig) {
        Warn "Can't use -delete_original when writing.\n";
        Warn "Maybe you meant -overwrite_original ?\n";
    } else {
        Warn "It makes no sense to use -restore_original when writing\n";
    }
    $rtnVal = 1;
    next;
}

if ($overwriteOrig > 1 and $outOpt) {
    Warn "Can't overwrite in place when -o option is used\n";
    $rtnVal = 1;
    next;
}

if ($tagOut and ($csv or %printFmt or $tabFormat or $xml or ($verbose and $html))) {
    Warn "Sorry, -W may not be combined with -csv, -htmlDump, -j, -p, -t or -X\n";
    $rtnVal = 1;
    next;
}

if ($csv and $csv eq 'CSV' and not $isWriting) {
    if ($textOut) {
        Warn "Sorry, -w may not be combined with -csv\n";
        $rtnVal = 1;
        next;
    }
    if ($binaryOutput) {
        $binaryOutput = 0;
        $setCharset = 'default' unless defined $setCharset;
    }
    require Image::ExifTool::XMP if $setCharset;
}

if ($escapeHTML or $json) {
    # must be UTF8 for HTML conversion and JSON output
    $mt->Options(Charset => 'UTF8') if $json;
    # use Escape option to do our HTML escaping unless XML output
    $mt->Options(Escape => 'HTML') if $escapeHTML and not $xml;
} elsif ($escapeXML and not $xml) {
    $mt->Options(Escape => 'XML');
}

# set sort option
if ($sortOpt) {
    # (note that -csv sorts alphabetically by default anyway if more than 1 file)
    my $sort = ($outFormat > 0 or $xml or $json or $csv) ? 'Tag' : 'Descr';
    $mt->Options(Sort => $sort, Sort2 => $sort);
}

# set $structOpt in case set by API option
if ($mt->Options('Struct') and not $structOpt) {
    $structOpt = $mt->Options('Struct');
    require 'Image/ExifTool/XMPStruct.pl';
}

# set up for RDF/XML, JSON and PHP output formats
if ($xml) {
    require Image::ExifTool::XMP;   # for EscapeXML()
    my $charset = $mt->Options('Charset');
    # standard XML encoding names for supported Charset settings
    # (ref http://www.iana.org/assignments/character-sets)
    my %encoding = (
        UTF8     => 'UTF-8',
        Latin    => 'windows-1252',
        Latin2   => 'windows-1250',
        Cyrillic => 'windows-1251',
        Greek    => 'windows-1253',
        Turkish  => 'windows-1254',
        Hebrew   => 'windows-1255',
        Arabic   => 'windows-1256',
        Baltic   => 'windows-1257',
        Vietnam  => 'windows-1258',
        MacRoman => 'macintosh',
    );
    # switch to UTF-8 if we don't have a standard encoding name
    unless ($encoding{$charset}) {
        $charset = 'UTF8';
        $mt->Options(Charset => $charset);
    }
    # set file header/trailer for XML output
    $fileHeader = "<?xml version='1.0' encoding='$encoding{$charset}'?>\n" .
                  "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>\n";
    $fileTrailer = "</rdf:RDF>\n";
    # extract as a list unless short output format
    $joinLists = 1 if $outFormat > 0;
    $mt->Options(List => 1) unless $joinLists;
    $showGroup = $allGroup = 1;         # always show group 1
    # set binaryOutput flag to 0 or undef (0 = output encoded binary in XML)
    $binaryOutput = ($outFormat > 0 ? undef : 0) if $binaryOutput;
    $showTagID = 'D' if $tabFormat and not $showTagID;
} elsif ($json) {
    if ($json == 1) { # JSON
        $fileHeader = '[';
        $fileTrailer = "]\n";
    } else { # PHP
        $fileHeader = 'Array(';
        $fileTrailer = ");\n";
    }
    # allow binary output in a text-mode file when -php/-json and -b used together
    # (this works because PHP strings are simple arrays of bytes, and CR/LF
    #  won't be messed up in the text mode output because they are converted
    #  to escape sequences in the strings)
    if ($binaryOutput) {
        $binaryOutput = 0;
        require Image::ExifTool::XMP if $json == 1;  # (for EncodeBase64)
    }
    $mt->Options(List => 1) unless $joinLists;
    $showTagID = 'D' if $tabFormat and not $showTagID;
} elsif ($structOpt) {
    $mt->Options(List => 1);
} else {
    $joinLists = 1;     # join lists for all other unstructured output formats
}

if ($argFormat) {
    $outFormat = 3;
    $allGroup = 1 if defined $showGroup;
}

# change to forward slashes if necessary in all filenames (like CleanFilename)
if ($hasBackslash{$^O}) {
    tr/\\/\// foreach @files;
}

# can't do anything if no file specified
unless (@files) {
    unless ($outOpt) {
        if ($doGlob and $doGlob == 2) {
            Warn "No matching files\n";
        } else {
            Warn "No file specified\n";
        }
        $rtnVal = 1;
        next;
    }
    push @files, '';    # create file from nothing
}

# set Verbose and HtmlDump options
if ($verbose) {
    $disableOutput = 1 unless @tags or @exclude or $tagOut;
    undef $binaryOutput unless $tagOut;    # disable conflicting option
    if ($html) {
        $html = 2;    # flag for html dump
        $mt->Options(HtmlDump => $verbose);
    } else {
        $mt->Options(Verbose => $verbose) unless $tagOut;
    }
} elsif (defined $verbose) {
    # auto-flush output when -v0 is used
    require FileHandle;
    STDOUT->autoflush(1);
    STDERR->autoflush(1);
}

# validate all tags we're writing
my $needSave = 1;
if (@newValues) {
    # assume -geotime value if -geotag specified without -geotime
    if ($addGeotime) {
        AddSetTagsFile($setTagsFile = '@') unless $setTagsFile and $setTagsFile eq '@';
        push @{$setTags{$setTagsFile}}, $addGeotime;
        $verbose and print $vout qq{Argument "-$addGeotime" is assumed\n};
    }
    my %setTagsIndex;
    # add/delete option lookup
    my %addDelOpt = ( '+' => 'AddValue', '-' => 'DelValue', "\xe2\x88\x92" => 'DelValue' );
    $saveCount = 0;
    foreach (@newValues) {
        if (ref $_ eq 'HASH') {
            # save new values now if we stored a "SaveCount" marker
            if ($$_{SaveCount}) {
                $saveCount = $mt->SaveNewValues();
                $needSave = 0;
                # insert marker to load values from CSV file now if this was the CSV file
                push @dynamicFiles, \$csv if $$_{SaveCount} == $csvSaveCount;
            }
            next;
        }
        /(.*?)=(.*)/s or next;
        my ($tag, $newVal) = ($1, $2);
        $tag =~ s/\ball\b/\*/ig;    # replace 'all' with '*' in tag names
        $newVal eq '' and undef $newVal unless $tag =~ s/\^([-+]*)$/$1/;  # undefined to delete tag
        if ($tag =~ /^(All)?TagsFromFile$/i) {
            defined $newVal or Error("Need file name for -tagsFromFile\n"), next Command;
            ++$isWriting;
            if ($newVal eq '@' or not defined FilenameSPrintf($newVal)) {
                push @dynamicFiles, $newVal;
                next;   # set tags from dynamic file later
            }
            unless ($mt->Exists($newVal) or $newVal eq '-') {
                Warn "File '${newVal}' does not exist for -tagsFromFile option\n";
                $rtnVal = 1;
                next Command;
            }
            my $setTags = $setTags{$newVal};
            # do we have multiple -tagsFromFile options with this file?
            if ($setTagsList{$newVal}) {
                # use the tags set in the i-th occurrence
                my $i = $setTagsIndex{$newVal} || 0;
                $setTagsIndex{$newVal} = $i + 1;
                $setTags = $setTagsList{$newVal}[$i] if $setTagsList{$newVal}[$i];
            }
            # set specified tags from this file
            unless (DoSetFromFile($mt, $newVal, $setTags)) {
                $rtnVal = 1;
                next Command;
            }
            $needSave = 1;
            next;
        }
        my %opts = ( Shift => 0 );  # shift values if possible instead of adding/deleting
        # allow writing of 'Unsafe' tags unless specified by wildcard
        $opts{Protected} = 1 unless $tag =~ /[?*]/;

        if ($tag =~ s/<// and defined $newVal) {
            if (defined FilenameSPrintf($newVal)) {
                SlurpFile($newVal, \$newVal) or next;   # read file data into $newVal
            } else {
                $tag =~ s/([-+]|\xe2\x88\x92)$// and $opts{$addDelOpt{$1}} = 1;
                # verify that this tag can be written
                my $result = Image::ExifTool::IsWritable($tag);
                if ($result) {
                    $opts{ProtectSaved} = $saveCount;   # protect new values set after this
                    # add to list of dynamic tag values
                    push @dynamicFiles, [ $tag, $newVal, \%opts ];
                    ++$isWriting;
                } elsif (defined $result) {
                    Warn "Tag '${tag}' is not writable\n";
                } else {
                    Warn "Tag '${tag}' does not exist\n";
                }
                next;
            }
        }
        if ($tag =~ s/([-+]|\xe2\x88\x92)$//) {
            $opts{$addDelOpt{$1}} = 1;  # set AddValue or DelValue option
            # set $newVal to '' if deleting nothing
            $newVal = '' if $1 eq '-' and not defined $newVal;
        }
        if ($escapeC and defined $newVal) {
            $newVal =~ s/\\(x([0-9a-fA-F]{2})|.)/$2 ? chr(hex($2)) : $unescC{$1} || $1/seg;
        }
        my ($rtn, $wrn) = $mt->SetNewValue($tag, $newVal, %opts);
        $needSave = 1;
        ++$isWriting if $rtn;
        $wrn and Warn "Warning: $wrn\n";
    }
    # exclude specified tags
    foreach (@exclude) {
        $mt->SetNewValue($_, undef, Replace => 2);
        $needSave = 1;
    }
    unless ($isWriting or $outOpt or @tags) {
        Warn "Nothing to do.\n";
        $rtnVal = 1;
        next;
    }
} elsif (grep /^(\*:)?\*$/, @exclude) {
    Warn "All tags excluded -- nothing to do.\n";
    $rtnVal = 1;
    next;
}
if ($isWriting and @tags and not $outOpt) {
    my ($tg, $s) = @tags > 1 ? ("$tags[0] ...", 's') : ($tags[0], '');
    Warn "Ignored superfluous tag name$s or invalid option$s: -$tg\n";
}
# save current state of new values if setting values from target file
# or if we may be translating to a different format
$mt->SaveNewValues() if $outOpt or (@dynamicFiles and $needSave);

$multiFile = 1 if @files > 1;
@exclude and $mt->Options(Exclude => \@exclude);

undef $binaryOutput if $html;

if ($binaryOutput) {
    $outFormat = 99;    # shortest possible output format
    $mt->Options(PrintConv => 0);
    unless ($textOut or $binaryStdout) {
        binmode(STDOUT);
        $binaryStdout = 1;
        $mt->Options(TextOut => ($vout = \*STDERR));
    }
    # disable conflicting options
    undef $showGroup;
}

# sort by groups to look nicer depending on options
if (defined $showGroup and not (@tags and $allGroup) and ($sortOpt or not defined $sortOpt)) {
    $mt->Options(Sort => "Group$showGroup");
}

if (defined $textOut) {
    CleanFilename($textOut);  # make all forward slashes
    # add '.' before output extension if necessary
    $textOut = ".$textOut" unless $textOut =~ /[.%]/ or defined $tagOut;
}

# determine if we should scan for only writable files
if ($outOpt) {
    my $type = GetFileType($outOpt);
    if ($type) {
        unless (CanWrite($type)) {
            Warn "Can't write $type files\n";
            $rtnVal = 1;
            next;
        }
        $scanWritable = $type unless CanCreate($type);
    } else {
        $scanWritable = 1;
    }
    $isWriting = 1;     # set writing flag
} elsif ($isWriting or defined $deleteOrig) {
    $scanWritable = 1;
}

# initialize alternate encoding flag
$altEnc = $mt->Options('Charset');
undef $altEnc if $altEnc eq 'UTF8';

# set flag to fix description lengths if necessary
if (not $altEnc and $mt->Options('Lang') ne 'en' and eval { require Encode }) {
    # (note that Unicode::GCString is part of the Unicode::LineBreak package)
    $fixLen = eval { require Unicode::GCString } ? 2 : 1;
}

# sort input files if specified
if (@fileOrder) {
    my @allFiles;
    ProcessFiles($mt, \@allFiles);
    my $sortTool = new Image::ExifTool;
    $sortTool->Options(FastScan => $fileOrderFast) if $fileOrderFast;
    $sortTool->Options(PrintConv => $mt->Options('PrintConv'));
    $sortTool->Options(Duplicates => 0);
    my (%sortBy, %isFloat, @rev, $file);
    # save reverse sort flags
    push @rev, (s/^-// ? 1 : 0) foreach @fileOrder;
    foreach $file (@allFiles) {
        my @tags;
        my $info = $sortTool->ImageInfo(Infile($file,1), @fileOrder, \@tags);
        # get values of all tags (or '~' to sort last if not defined)
        foreach (@tags) {
            $_ = $$info{$_};    # put tag value into @tag list
            defined $_ or $_ = '~', next;
            $isFloat{$_} = Image::ExifTool::IsFloat($_);
            # pad numbers to 12 digits to keep them sequential
            s/(\d+)/(length($1) < 12 ? '0'x(12-length($1)) : '') . $1/eg unless $isFloat{$_};
        }
        $sortBy{$file} = \@tags;    # save tag values for each file
    }
    # sort in specified order
    @files = sort {
        my ($i, $cmp);
        for ($i=0; $i<@rev; ++$i) {
            my $u = $sortBy{$a}[$i];
            my $v = $sortBy{$b}[$i];
            if (not $isFloat{$u} and not $isFloat{$v}) {
                $cmp = $u cmp $v;               # alphabetically
            } elsif ($isFloat{$u} and $isFloat{$v}) {
                $cmp = $u <=> $v;               # numerically
            } else {
                $cmp = $isFloat{$u} ? -1 : 1;   # numbers first
            }
            return $rev[$i] ? -$cmp : $cmp if $cmp;
        }
        return $a cmp $b;   # default to sort by name
    } @allFiles;
} elsif (defined $progress) {
    # expand FILE argument to count the number of files to process
    my @allFiles;
    ProcessFiles($mt, \@allFiles);
    @files = @allFiles;
}
# set file count for progress message
$progressMax = scalar @files if defined $progress;

# store duplicate database information under absolute path
my @dbKeys = keys %database;
if (@dbKeys) {
    if (eval { require Cwd }) {
        undef $evalWarning;
        local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
        foreach (@dbKeys) {
            my $db = $database{$_};
            tr/\\/\// and $database{$_} = $db;  # allow for backslashes in SourceFile
            # (punt on using ConvertFileName here, so $absPath may be a mix of encodings)
            my $absPath = AbsPath($_);
            if (defined $absPath) {
                $database{$absPath} = $db unless $database{$absPath};
                if ($verbose and $verbose > 1) {
                    print $vout "Imported entry for '${_}' (full path: '${absPath}')\n";
                }
            } elsif ($verbose and $verbose > 1) {
                print $vout "Imported entry for '${_}' (non-existent file)\n";
            }
        }
    }
}

# process all specified files
ProcessFiles($mt);

if ($filtered and not $validFile) {
    Warn "No file with specified extension\n";
    $rtnVal = 1;
}

# print CSV information if necessary
PrintCSV() if $csv and not $isWriting;

# print folder/file trailer if necessary
print $sectTrailer if $sectTrailer and not $textOut;
print $fileTrailer if $fileTrailer and not $textOut and not $fileHeader;

my $totWr = $countGoodWr + $countBadWr + $countSameWr + $countCopyWr +
            $countGoodCr + $countBadCr;

if (defined $deleteOrig) {

    # print summary and delete requested files
    unless ($quiet) {
        printf "%5d directories scanned\n", $countDir if $countDir;
        printf "%5d directories created\n", $countNewDir if $countNewDir;
        printf "%5d files failed condition\n", $countFailed if $countFailed;
        printf "%5d image files found\n", $count;
    }
    if (@delFiles) {
        # verify deletion unless "-delete_original!" was specified
        if ($deleteOrig == 1) {
            printf '%5d originals will be deleted!  Are you sure [y/n]? ', scalar(@delFiles);
            my $response = <STDIN>;
            unless ($response =~ /^(y|yes)\s*$/i) {
                Warn "Originals not deleted.\n";
                next;
            }
        }
        $countGoodWr = $mt->Unlink(@delFiles);
        $countBad = scalar(@delFiles) - $countGoodWr;
    }
    if ($quiet) {
        # no more messages
    } elsif ($count and not $countGoodWr and not $countBad) {
        printf "%5d original files found\n", $countGoodWr; # (this will be 0)
    } elsif ($deleteOrig) {
        printf "%5d original files deleted\n", $countGoodWr if $count;
        printf "%5d originals not deleted due to errors\n", $countBad if $countBad;
    } else {
        printf "%5d image files restored from original\n", $countGoodWr if $count;
        printf "%5d files not restored due to errors\n", $countBad if $countBad;
    }

} elsif ((not $binaryStdout or $verbose) and not $quiet) {

    # print summary
    my $tot = $count + $countBad;
    if ($countDir or $totWr or $countFailed or $tot > 1 or $textOut or %countLink) {
        my $o = (($html or $json or $xml or %printFmt or $csv) and not $textOut) ? \*STDERR : $vout;
        printf($o "%5d directories scanned\n", $countDir) if $countDir;
        printf($o "%5d directories created\n", $countNewDir) if $countNewDir;
        printf($o "%5d files failed condition\n", $countFailed) if $countFailed;
        printf($o "%5d image files created\n", $countGoodCr) if $countGoodCr;
        printf($o "%5d image files updated\n", $countGoodWr) if $totWr - $countGoodCr - $countBadCr - $countCopyWr;
        printf($o "%5d image files unchanged\n", $countSameWr) if $countSameWr;
        printf($o "%5d image files %s\n", $countCopyWr, $overwriteOrig ? 'moved' : 'copied') if $countCopyWr;
        printf($o "%5d files weren't updated due to errors\n", $countBadWr) if $countBadWr;
        printf($o "%5d files weren't created due to errors\n", $countBadCr) if $countBadCr;
        printf($o "%5d image files read\n", $count) if ($tot+$countFailed)>1 or ($countDir and not $totWr);
        printf($o "%5d files could not be read\n", $countBad) if $countBad;
        printf($o "%5d output files created\n", scalar(keys %created)) if $textOut;
        printf($o "%5d output files appended\n", scalar(keys %appended)) if %appended;
        printf($o "%5d hard links created\n", $countLink{Hard} || 0) if $countLink{Hard} or $countLink{BadHard};
        printf($o "%5d hard links could not be created\n", $countLink{BadHard}) if $countLink{BadHard};
        printf($o "%5d symbolic links created\n", $countLink{Sym} || 0) if $countLink{Sym} or $countLink{BadSym};
        printf($o "%5d symbolic links could not be created\n", $countLink{BadSym}) if $countLink{BadSym};
    }
}

# set error status if we had any errors or if all files failed the "-if" condition
if ($countBadWr or $countBadCr or $countBad) {
    $rtnVal = 1;
} elsif ($countFailed and not ($count or $totWr) and not $rtnVal) {
    $rtnVal = 2;
}

# clean up after each command
Cleanup();

} # end "Command" loop ........................................................

close STAYOPEN if $stayOpen >= 2;

Exit $rtnValApp;    # all done


#------------------------------------------------------------------------------
# Get image information from EXIF data in file (or write file if writing)
# Inputs: 0) ExifTool object reference, 1) file name
sub GetImageInfo($$)
{
    my ($et, $orig) = @_;
    my (@foundTags, $info, $file, $ind);

    # set window title for this file if necessary
    if (defined $windowTitle) {
        my $prog = $progressMax ? "$progressCount/$progressMax" : '0/0';
        my $title = $windowTitle;
        my ($num, $denom) = split '/', $prog;
        my $frac = $num / ($denom || 1);
        my $n = $title =~ s/%(\d+)b/%b/ ? $1 : 20;  # length of bar
        my $bar = int($frac * $n + 0.5);
        my %lkup = (
            b => ('I' x $bar) . ('.' x ($n - $bar)), # (undocumented)
            f => $orig,
            p => int(100 * $frac + 0.5),
            r => $prog,
           '%'=> '%',
        );
        $title =~ s/%([%bfpr])/$lkup{$1}/eg;
        SetWindowTitle($title);
    }
    unless (length $orig or $outOpt) {
        Warn qq(Error: Zero-length file name - ""\n);
        ++$countBad;
        return;
    }
    # determine the name of the source file based on the original input file name
    if (@srcFmt) {
        my ($fmt, $first);
        foreach $fmt (@srcFmt) {
            $file = $fmt eq '@' ? $orig : FilenameSPrintf($fmt, $orig);
            # use this file if it exists
            $et->Exists($file) and undef($first), last;
            $verbose and print $vout "Source file $file does not exist\n";
            $first = $file unless defined $first;
        }
        $file = $first if defined $first;
        my ($d, $f) = Image::ExifTool::SplitFileName($orig);
        $et->Options(UserParam => "OriginalDirectory#=$d");
        $et->Options(UserParam => "OriginalFileName#=$f");
    } else {
        $file = $orig;
    }

    my $pipe = $file;
    if ($doUnzip) {
        # pipe through gzip or bzip2 if necessary
        if ($file =~ /\.(gz|bz2)$/i) {
            my $type = lc $1;
            if ($file =~ /[^-_.'A-Za-z0-9\/\\]/) {
                Warn "Error: Insecure zip file name. Skipped\n";
                EFile($file);
                ++$countBad;
                return;
            }
            if ($type eq 'gz') {
                $pipe = qq{gzip -dc "$file" |};
            } else {
                $pipe = qq{bzip2 -dc "$file" |};
            }
        }
    }
    # evaluate -if expression for conditional processing
    if (@condition) {
        unless ($file eq '-' or $et->Exists($file)) {
            Warn "Error: File not found - $file\n";
            EFile($file);
            FileNotFound($file);
            ++$countBad;
            return;
        }
        my $result;

        unless ($failCondition) {
            # catch run time errors as well as compile errors
            undef $evalWarning;
            local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };

            my (%info, $condition);
            # extract information and build expression for evaluation
            my $opts = { Duplicates => 1, RequestTags => \@requestTags, Verbose => 0, HtmlDump => 0 };
            $$opts{FastScan} = $fastCondition if defined $fastCondition;
            # return all tags but explicitly mention tags on command line so
            # requested images will generate the appropriate warnings
            @foundTags = ('*', @tags) if @tags;
            $info = $et->ImageInfo(Infile($pipe,$isWriting), \@foundTags, $opts);
            foreach $condition (@condition) {
                my $cond = $et->InsertTagValues(\@foundTags, $condition, \%info);
                {
                    # set package so eval'd functions are in Image::ExifTool namespace
                    package Image::ExifTool;

                    my $self = $et;
                    #### eval "-if" condition (%info, $self)
                    $result = eval $cond;

                    $@ and $evalWarning = $@;
                }
                if ($evalWarning) {
                    # fail condition if warning is issued
                    undef $result;
                    if ($verbose) {
                        chomp $evalWarning;
                        $evalWarning =~ s/ at \(eval .*//s;
                        Warn "Condition: $evalWarning - $file\n";
                    }
                }
                last unless $result;
            }
            undef @foundTags if $fastCondition; # ignore if we didn't get all tags
        }
        unless ($result) {
            $verbose and print $vout "-------- $file (failed condition)$progStr\n";
            EFile($file, 2);
            ++$countFailed;
            return;
        }
        # can't make use of $info if verbose because we must reprocess
        # the file anyway to generate the verbose output
        undef $info if $verbose or defined $fastCondition;
    }
    if (defined $deleteOrig) {
        print $vout "======== $file$progStr\n" if defined $verbose;
        ++$count;
        my $original = "${file}_original";
        $et->Exists($original) or return;
        if ($deleteOrig) {
            $verbose and print $vout "Scheduled for deletion: $original\n";
            push @delFiles, $original;
        } elsif ($et->Rename($original, $file)) {
            $verbose and print $vout "Restored from $original\n";
            ++$countGoodWr;
        } else {
            Warn "Error renaming $original\n";
            EFile($file);
            ++$countBad;
        }
        return;
    }
    ++$seqFileNum;  # increment our file counter

    my $lineCount = 0;
    my ($fp, $outfile, $append);
    if ($textOut and $verbose and not $tagOut) {
        ($fp, $outfile, $append) = OpenOutputFile($orig);
        $fp or EFile($file), ++$countBad, return;
        # delete file if we exit prematurely (unless appending)
        $tmpText = $outfile unless $append;
        $et->Options(TextOut => $fp);
    }

    if ($isWriting) {
        print $vout "======== $file$progStr\n" if defined $verbose;
        SetImageInfo($et, $file, $orig);
        $info = $et->GetInfo('Warning', 'Error');
        PrintErrors($et, $info, $file);
        # close output text file if necessary
        if ($outfile) {
            undef $tmpText;
            close($fp);
            $et->Options(TextOut => $vout);
            if ($info->{Error}) {
                $et->Unlink($outfile);  # erase bad file
            } elsif ($append) {
                $appended{$outfile} = 1 unless $created{$outfile};
            } else {
                $created{$outfile} = 1;
            }
        }
        return;
    }

    # extract information from this file
    unless ($file eq '-' or $et->Exists($file)) {
        Warn "Error: File not found - $file\n";
        FileNotFound($file);
        $outfile and close($fp), undef($tmpText), $et->Unlink($outfile);
        EFile($file);
        ++$countBad;
        return;
    }
    # print file/progress message
    my $o;
    unless ($binaryOutput or $textOut or %printFmt or $html > 1 or $csv) {
        if ($html) {
            require Image::ExifTool::HTML;
            my $f = Image::ExifTool::HTML::EscapeHTML($file);
            print "<!-- $f -->\n";
        } elsif (not ($json or $xml)) {
            $o = \*STDOUT if ($multiFile and not $quiet) or $progress;
        }
    }
    $o = \*STDERR if $progress and not $o;
    $o and print $o "======== $file$progStr\n";
    if ($info) {
        # get the information we wanted
        if (@tags and not %printFmt) {
            @foundTags = @tags;
            $info = $et->GetInfo(\@foundTags);
        }
    } else {
        # request specified tags unless using print format option
        my $oldDups = $et->Options('Duplicates');
        if (%printFmt) {
            $et->Options(Duplicates => 1);
            $et->Options(RequestTags => \@requestTags);
        } else {
            @foundTags = @tags;
        }
        # extract the information
        $info = $et->ImageInfo(Infile($pipe), \@foundTags);
        $et->Options(Duplicates => $oldDups);
    }
    # all done now if we already wrote output text file (eg. verbose option)
    if ($fp) {
        if ($outfile) {
            $et->Options(TextOut => \*STDOUT);
            undef $tmpText;
            if ($info->{Error}) {
                close($fp);
                $et->Unlink($outfile);  # erase bad file
            } else {
                ++$lineCount;       # output text file (likely) is not empty
            }
        }
        if ($info->{Error}) {
            Warn "Error: $info->{Error} - $file\n";
            EFile($file);
            ++$countBad;
            return;
        }
    }

    # print warnings to stderr if using binary output
    # (because we are likely ignoring them and piping stdout to file)
    # or if there is none of the requested information available
    if ($binaryOutput or not %$info) {
        my $errs = $et->GetInfo('Warning', 'Error');
        PrintErrors($et, $errs, $file) and EFile($file), $rtnVal = 1;
    } elsif ($et->GetValue('Error') or ($$et{Validate} and $et->GetValue('Warning'))) {
        $rtnVal = 1;
    }

    # open output file (or stdout if no output file) if not done already
    unless ($outfile or $tagOut) {
        ($fp, $outfile, $append) = OpenOutputFile($orig);
        $fp or EFile($file), ++$countBad, return;
        $tmpText = $outfile unless $append;
    }

    # print the results for this file
    if (%printFmt) {
        # output using print format file (-p) option
        my ($type, $doc, $grp, $lastDoc, $cache);
        $fileTrailer = '';
        # repeat for each embedded document if necessary
        if ($et->Options('ExtractEmbedded')) {
            # (cache tag keys if there are sub-documents)
            $lastDoc = $$et{DOC_COUNT} and $cache = { };
        } else {
            $lastDoc = 0;
        }
        for ($doc=0; $doc<=$lastDoc; ++$doc) {
            my $skipBody;
            foreach $type (qw(HEAD SECT IF BODY ENDS TAIL)) {
                my $prf = $printFmt{$type} or next;
                next if $type eq 'BODY' and $skipBody;
                if ($lastDoc) {
                    if ($doc) {
                        next if $type eq 'HEAD' or $type eq 'TAIL'; # only repeat SECT/IF/BODY/ENDS
                        $grp = "Doc$doc";
                    } else {
                        $grp = 'Main';
                    }
                }
                my @lines;
                my $opt = $type eq 'IF' ? 'Silent' : 'Warn'; # silence "IF" warnings
                foreach (@$prf) {
                    my $line = $et->InsertTagValues(\@foundTags, $_, $opt, $grp, $cache);
                    if ($type eq 'IF') {
                        $skipBody = 1 unless defined $line;
                    } elsif (defined $line) {
                        push @lines, $line;
                    }
                }
                $lineCount += scalar @lines;
                if ($type eq 'SECT') {
                    my $thisHeader = join '', @lines;
                    if ($sectHeader and $sectHeader ne $thisHeader) {
                        print $fp $sectTrailer if $sectTrailer;
                        undef $sectHeader;
                    }
                    $sectTrailer = '';
                    print $fp $sectHeader = $thisHeader unless $sectHeader;
                } elsif ($type eq 'ENDS') {
                    $sectTrailer .= join '', @lines if defined $sectHeader;
                } elsif ($type eq 'TAIL') {
                    $fileTrailer .= join '', @lines;
                } elsif (@lines) {
                    print $fp @lines;
                }
            }
        }
        delete $printFmt{HEAD} unless $outfile; # print header only once per output file
        my $errs = $et->GetInfo('Warning', 'Error');
        PrintErrors($et, $errs, $file) and EFile($file);
    } elsif (not $disableOutput) {
        my ($tag, $line, %noDups, %csvInfo, $bra, $ket, $sep);
        if ($fp) {
            # print file header (only once)
            if ($fileHeader) {
                print $fp $fileHeader;
                undef $fileHeader unless $textOut;
            }
            if ($html) {
                print $fp "<table>\n";
            } elsif ($xml) {
                my $f = $file;
                CleanXML(\$f);
                print $fp "\n<rdf:Description rdf:about='${f}'";
                print $fp "\n  xmlns:et='http://ns.exiftool.org/1.0/'";
                print $fp " et:toolkit='Image::ExifTool $Image::ExifTool::VERSION'";
                # define namespaces for all tag groups
                my (%groups, @groups, $grp0, $grp1);
                foreach $tag (@foundTags) {
                    ($grp0, $grp1) = $et->GetGroup($tag);
                    unless ($grp1) {
                        next unless defined $forcePrint;
                        $grp0 = $grp1 = 'Unknown';
                    }
                    next if $groups{$grp1};
                    # include family 0 and 1 groups in URI except for internal tags
                    # (this will put internal tags in the "XML" group on readback)
                    $groups{$grp1} = $grp0;
                    push @groups, $grp1;
                    AddGroups($$info{$tag}, $grp0, \%groups, \@groups) if ref $$info{$tag};
                }
                foreach $grp1 (@groups) {
                    my $grp = $groups{$grp1};
                    unless ($grp eq $grp1 and $grp =~ /^(ExifTool|File|Composite|Unknown)$/) {
                        $grp .= "/$grp1";
                    }
                    print $fp "\n  xmlns:$grp1='http://ns.exiftool.org/$grp/1.0/'";
                }
                print $fp '>' if $outFormat < 1; # finish rdf:Description token unless short format
                $ind = $outFormat >= 0 ? ' ' : '   ';
            } elsif ($json) {
                # set delimiters for JSON or PHP output
                ($bra, $ket, $sep) = $json == 1 ? ('{','}',':') : ('Array(',')',' =>');
                print $fp ",\n" if $comma;
                print $fp qq($bra\n  "SourceFile"$sep ), EscapeJSON(MyConvertFileName($et,$file));
                $comma = 1;
                $ind = (defined $showGroup and not $allGroup) ? '    ' : '  ';
            } elsif ($csv) {
                my $file2 = MyConvertFileName($et, $file);
                $database{$file2} = \%csvInfo;
                push @csvFiles, $file2;
            }
        }
        # suppress duplicates manually in JSON and short XML output
        my $noDups = ($json or ($xml and $outFormat > 0));
        my $printConv = $et->Options('PrintConv');
        my $lastGroup = '';
        my $i = -1;
TAG:    foreach $tag (@foundTags) {
            ++$i;   # keep track on index in @foundTags
            my $tagName = GetTagName($tag);
            my ($group, $valList);
            # get the value for this tag
            my $val = $$info{$tag};
            # set flag if this is binary data
            $isBinary = (ref $val eq 'SCALAR' and defined $binaryOutput);
            if (ref $val) {
                # happens with -X, -j or -php when combined with -b:
                if (defined $binaryOutput and not $binaryOutput and $$et{TAG_INFO}{$tag}{Protected}) {
                    # avoid extracting Protected binary tags (eg. data blocks) [insider information]
                    my $lcTag = lc $tag;
                    $lcTag =~ s/ .*//;
                    next unless $$et{REQ_TAG_LOOKUP}{$lcTag} or ($$et{OPTIONS}{RequestAll} || 0) > 2;
                }
                $val = ConvertBinary($val); # convert SCALAR references
                next unless defined $val;
                if ($structOpt and ref $val) {
                    # serialize structure if necessary
                    $val = Image::ExifTool::XMP::SerializeStruct($val) unless $xml or $json;
                } elsif (ref $val eq 'ARRAY') {
                    if (defined $listItem) {
                        # take only the specified item
                        $val = $$val[$listItem];
                    # join arrays of simple values (with newlines for binary output)
                    } elsif ($binaryOutput) {
                        if ($tagOut) {
                            $valList = $val;
                            $val = shift @$valList;
                        } else {
                            $val = join defined $binSep ? $binSep : "\n", @$val;
                        }
                    } elsif ($joinLists) {
                        $val = join $listSep, @$val;
                    }
                }
            }
            if (not defined $val) {
                # ignore tags that weren't found unless necessary
                next if $binaryOutput;
                if (defined $forcePrint) {
                    $val = $forcePrint; # forced to print all tag values
                } elsif (not $csv) {
                    next;
                }
            }
            if (defined $showGroup) {
                $group = $et->GetGroup($tag, $showGroup);
                # look ahead to see if this tag may suppress a priority tag in
                # the same group, and if so suppress this tag instead
                next if $noDups and $tag =~ /^(.*?) \(/ and defined $$info{$1} and
                        $group eq $et->GetGroup($1, $showGroup);
                $group = 'Unknown' if not $group and ($xml or $json or $csv);
                if ($fp and not ($allGroup or $csv)) {
                    if ($lastGroup ne $group) {
                        if ($html) {
                            my $cols = 1;
                            ++$cols if $outFormat==0 or $outFormat==1;
                            ++$cols if $showTagID;
                            print $fp "<tr><td colspan=$cols bgcolor='#dddddd'>$group</td></tr>\n";
                        } elsif ($json) {
                            print $fp "\n  $ket" if $lastGroup;
                            print $fp ',' if $lastGroup or $comma;
                            print $fp qq(\n  "$group"$sep $bra);
                            undef $comma;
                            undef %noDups;  # allow duplicate names in different groups
                        } else {
                            print $fp "---- $group ----\n";
                        }
                        $lastGroup = $group;
                    }
                    undef $group;   # undefine so we don't print it below
                }
            } elsif ($noDups) {
                # don't allow duplicates, but avoid suppressing the priority tag
                next if $tag =~ /^(.*?) \(/ and defined $$info{$1};
            }

            ++$lineCount;           # we are printing something meaningful

            # loop through list values when -b -W used
            for (;;) {
                if ($tagOut) {
                    # determine suggested extension for output file
                    my $ext = SuggestedExtension($et, \$val, $tagName);
                    if (%wext and ($wext{$ext} || $wext{'*'} || -1) < 0) {
                        if ($verbose and $verbose > 1) {
                            print $vout "Not writing $ext output file for $tagName\n";
                        }
                        next TAG;
                    }
                    my @groups = $et->GetGroup($tag);
                    $outfile and close($fp), undef($tmpText); # (shouldn't happen)
                    ($fp, $outfile, $append) = OpenOutputFile($orig, $tagName, \@groups, $ext);
                    $fp or ++$countBad, next TAG;
                    $tmpText = $outfile unless $append;
                }
                # write binary output
                if ($binaryOutput) {
                    print $fp $val;
                    print $fp $binTerm if defined $binTerm;
                    if ($tagOut) {
                        if ($append) {
                            $appended{$outfile} = 1 unless $created{$outfile};
                        } else {
                            $created{$outfile} = 1;
                        }
                        close($fp);
                        undef $tmpText;
                        $verbose and print $vout "Wrote $tagName to $outfile\n";
                        undef $outfile;
                        undef $fp;
                        next TAG unless $valList and @$valList;
                        $val = shift @$valList;
                        next; # loop over values of List tag
                    }
                    next TAG;
                }
                last;
            }
            # save information for CSV output
            if ($csv) {
                my $tn = $tagName;
                $tn .= '#' if $tag =~ /#/;  # add ValueConv "#" suffix if used
                my $gt = $group ? "$group:$tn" : $tn;
                # (tag-name case may be different if some tags don't exist
                # in a file, so all logic must use lower-case tag names)
                my $lcTag = lc $gt;
                # override existing entry only if top priority
                next if defined $csvInfo{$lcTag} and $tag =~ /\(/;
                $csvInfo{$lcTag} = $val;
                if (defined $csvTags{$lcTag}) {
                    # overwrite with actual extracted tag name
                    # (note: can't check "if defined $val" here because -f may be used)
                    $csvTags{$lcTag} = $gt if defined $$info{$tag};
                    next;
                }
                # must check for "Unknown" group (for tags that don't exist)
                if ($group and defined $csvTags[$i] and $csvTags[$i] =~ /^(.*):$tn$/i) {
                     next if $group eq 'Unknown';   # nothing more to do if we don't know tag group
                     if ($1 eq 'unknown') {
                        # replace unknown entry in CSV tag lookup and list
                        delete $csvTags{$csvTags[$i]};
                        $csvTags{$lcTag} = defined($val) ? $gt : '';
                        $csvTags[$i] = $lcTag;
                        next;
                     }
                }
                # (don't save unextracted tag name unless -f was used)
                $csvTags{$lcTag} = defined($val) ? $gt : '';
                if (@csvFiles == 1) {
                    push @csvTags, $lcTag; # save order of tags for first file
                } elsif (@csvTags) {
                    undef @csvTags;
                }
                next;
            }

            # get description if we need it (use tag name if $outFormat > 0)
            my $desc = $outFormat > 0 ? $tagName : $et->GetDescription($tag);

            if ($xml) {
                # RDF/XML output format
                my $tok = "$group:$tagName";
                if ($outFormat > 0) {
                    if ($structOpt and ref $val) {
                        $val = Image::ExifTool::XMP::SerializeStruct($val);
                    }
                    if ($escapeHTML) {
                        $val =~ tr/\0-\x08\x0b\x0c\x0e-\x1f/./;
                        Image::ExifTool::XMP::FixUTF8(\$val) unless $altEnc;
                        $val = Image::ExifTool::HTML::EscapeHTML($val, $altEnc);
                    } else {
                        CleanXML(\$val);
                    }
                    unless ($noDups{$tok}) {
                        # manually un-do CR/LF conversion in Windows because output
                        # is in text mode, which will re-convert newlines to CR/LF
                        $isCRLF and $val =~ s/\x0d\x0a/\x0a/g;
                        print $fp "\n $tok='${val}'";
                        # XML does not allow duplicate attributes
                        $noDups{$tok} = 1;
                    }
                    next;
                }
                my ($xtra, $valNum, $descClose);
                if ($showTagID) {
                    my ($id, $lang) = $et->GetTagID($tag);
                    if ($id =~ /^\d+$/) {
                        $id = sprintf("0x%.4x", $id) if $showTagID eq 'H';
                    } else {
                        $id = Image::ExifTool::XMP::FullEscapeXML($id);
                    }
                    $xtra = " et:id='${id}'";
                    $xtra .= " xml:lang='${lang}'" if $lang;
                } else {
                    $xtra = '';
                }
                if ($tabFormat) {
                    my $table = $et->GetTableName($tag);
                    my $index = $et->GetTagIndex($tag);
                    $xtra .= " et:table='${table}'";
                    $xtra .= " et:index='${index}'" if defined $index;
                }
                my $lastVal = $val;
                for ($valNum=0; $valNum<2; ++$valNum) {
                    $val = FormatXML($val, $ind, $group);
                    # manually un-do CR/LF conversion in Windows because output
                    # is in text mode, which will re-convert newlines to CR/LF
                    $isCRLF and $val =~ s/\x0d\x0a/\x0a/g;
                    if ($outFormat >= 0) {
                        # normal output format (note: this will give
                        # non-standard RDF/XML if there are any attributes)
                        print $fp "\n <$tok$xtra$val</$tok>";
                        last;
                    } elsif ($valNum == 0) {
                        CleanXML(\$desc);
                        if ($xtra) {
                            print $fp "\n <$tok>";
                            print $fp "\n  <rdf:Description$xtra>";
                            $descClose = "\n  </rdf:Description>";
                        } else {
                            print $fp "\n <$tok rdf:parseType='Resource'>";
                            $descClose = '';
                        }
                        # print tag Description
                        print $fp "\n   <et:desc>$desc</et:desc>";
                        if ($printConv) {
                            # print PrintConv value
                            print $fp "\n   <et:prt$val</et:prt>";
                            $val = $et->GetValue($tag, 'ValueConv');
                            $val = '' unless defined $val;
                            # go back to print ValueConv value only if different
                            next unless IsEqual($val, $lastVal);
                            print $fp "$descClose\n </$tok>";
                            last;
                        }
                    }
                    # print ValueConv value
                    print $fp "\n   <et:val$val</et:val>";
                    print $fp "$descClose\n </$tok>";
                    last;
                }
                next;
            } elsif ($json) {
                # JSON or PHP output format
                my $tok = $allGroup ? "$group:$tagName" : $tagName;
                # (removed due to backward incompatibility)
                # $tok .= '#' if $tag =~ /#/; # add back '#' suffix if used
                next if $noDups{$tok};
                $noDups{$tok} = 1;
                print $fp ',' if $comma;
                print $fp qq(\n$ind"$tok"$sep );
                if ($showTagID or $outFormat < 0) {
                    $val = { val => $val };
                    if ($showTagID) {
                        my $id = $et->GetTagID($tag);
                        $id = sprintf('0x%.4x', $id) if $showTagID eq 'H' and $id =~ /^\d+$/;
                        $$val{id} = $id;
                    }
                    if ($tabFormat) {
                        $$val{table} = $et->GetTableName($tag);
                        my $index = $et->GetTagIndex($tag);
                        $$val{index} = $index if defined $index;
                    }
                    if ($outFormat < 0) {
                        $$val{desc} = $desc;
                        if ($printConv) {
                            my $num = $et->GetValue($tag, 'ValueConv');
                            $$val{num} = $num if defined $num and not IsEqual($num, $$val{val});
                        }
                    }
                }
                FormatJSON($fp, $val, $ind);
                $comma = 1;
                next;
            }
            my $id;
            if ($showTagID) {
                $id = $et->GetTagID($tag);
                if ($id =~ /^(\d+)(\.\d+)?$/) { # only print numeric ID's
                    $id = sprintf("0x%.4x", $1) if $showTagID eq 'H';
                } else {
                    $id = '-';
                }
            }

            if ($escapeC) {
                $val =~ s/([\0-\x1f\\\x7f])/$escC{$1} || sprintf('\x%.2x', ord $1)/eg;
            } else {
                # translate unprintable chars in value and remove trailing spaces
                $val =~ tr/\x01-\x1f\x7f/./;
                $val =~ s/\x00//g;
                $val =~ s/\s+$//;
            }

            if ($html) {
                print $fp "<tr>";
                print $fp "<td>$group</td>" if defined $group;
                print $fp "<td>$id</td>" if $showTagID;
                print $fp "<td>$desc</td>" if $outFormat <= 1;
                print $fp "<td>$val</td></tr>\n";
            } else {
                my $buff = '';
                if ($tabFormat) {
                    $buff = "$group\t" if defined $group;
                    $buff .= "$id\t" if $showTagID;
                    if ($outFormat <= 1) {
                        $buff .= "$desc\t$val\n";
                    } elsif (defined $line) {
                        $line .= "\t$val";
                    } else {
                        $line = $val;
                    }
                } elsif ($outFormat < 0) {    # long format
                    $buff = "[$group] " if defined $group;
                    $buff .= "$id " if $showTagID;
                    $buff .= "$desc\n      $val\n";
                } elsif ($outFormat == 0 or $outFormat == 1) {
                    my $wid;
                    my $len = 0;
                    if (defined $group) {
                        $buff = sprintf("%-15s ", "[$group]");
                        $len = 16;
                    }
                    if ($showTagID) {
                        $wid = ($showTagID eq 'D') ? 5 : 6;
                        $len += $wid + 1;
                        ($wid = $len - length($buff) - 1) < 1 and $wid = 1;
                        $buff .= sprintf "%${wid}s ", $id;
                    }
                    $wid = 32 - (length($buff) - $len);
                    # pad description to a constant length
                    # (get actual character length when using alternate languages
                    # because these descriptions may contain UTF8-encoded characters)
                    my $padLen = $wid;
                    if (not $fixLen) {
                        $padLen -= length $desc;
                    } elsif ($fixLen == 1) {
                        $padLen -= length Encode::decode_utf8($desc);
                    } else {
                        my $gcstr = eval { new Unicode::GCString(Encode::decode_utf8($desc)) };
                        if ($gcstr) {
                            $padLen -= $gcstr->columns;
                        } else {
                            $padLen -= length Encode::decode_utf8($desc);
                            Warn "Warning: Unicode::GCString problem.  Columns may be misaligned\n";
                            $fixLen = 1;
                        }
                    }
                    $padLen = 0 if $padLen < 0;
                    $buff .= $desc . (' ' x $padLen) . ": $val\n";
                } elsif ($outFormat == 2) {
                    $buff = "[$group] " if defined $group;
                    $buff .= "$id " if $showTagID;
                    $buff .= "$tagName: $val\n";
                } elsif ($argFormat) {
                    $buff = '-';
                    $buff .= "$group:" if defined $group;
                    $tagName .= '#' if $tag =~ /#/; # add '#' suffix if used
                    $buff .= "$tagName=$val\n";
                } else {
                    $buff = "$group " if defined $group;
                    $buff .= "$id " if $showTagID;
                    $buff .= "$val\n";
                }
                print $fp $buff;
            }
            if ($tagOut) {
                if ($append) {
                    $appended{$outfile} = 1 unless $created{$outfile};
                } else {
                    $created{$outfile} = 1;
                }
                close($fp);
                undef $tmpText;
                $verbose and print $vout "Wrote $tagName to $outfile\n";
                undef $outfile;
                undef $fp;
            }
        }
        if ($fp) {
            if ($html) {
                print $fp "</table>\n";
            } elsif ($xml) {
                # close rdf:Description element
                print $fp $outFormat < 1 ? "\n</rdf:Description>\n" : "/>\n";
            } elsif ($json) {
                print $fp "\n  $ket" if $lastGroup;
                print $fp "\n$ket";
                $comma = 1;
            } elsif ($tabFormat and $outFormat > 1) {
                print $fp "$line\n" if defined $line;
            }
        }
    }
    if ($outfile) {
        # write section and file trailers before closing the file
        print $fp $sectTrailer and $sectTrailer = '' if $sectTrailer;
        print $fp $fileTrailer if $fileTrailer;
        close($fp);
        undef $tmpText;
        if ($lineCount) {
            if ($append) {
                $appended{$outfile} = 1 unless $created{$outfile};
            } else {
                $created{$outfile} = 1;
            }
        } else {
            $et->Unlink($outfile) unless $append; # don't keep empty output files
        }
        undef $comma;
    }
    ++$count;
}

#------------------------------------------------------------------------------
# Set information in file
# Inputs: 0) ExifTool object reference, 1) source file name
#         2) original source file name ('' to create from scratch)
# Returns: true on success
sub SetImageInfo($$$)
{
    my ($et, $file, $orig) = @_;
    my ($outfile, $restored, $isTemporary, $isStdout, $outType, $tagsFromSrc);
    my ($hardLink, $symLink, $testName, $sameFile);
    my $infile = $file;    # save infile in case we change it again

    # clean up old temporary file if necessary
    if (defined $tmpFile) {
        $et->Unlink($tmpFile);
        undef $tmpFile;
    }
    # clear any existing errors or warnings since we check these on return
    delete $$et{VALUE}{Error};
    delete $$et{VALUE}{Warning};

    # first, try to determine our output file name so we can return quickly
    # if it already exists (note: this test must be delayed until after we
    # set tags from dynamic files if writing FileName or Directory)
    if (defined $outOpt) {
        if ($outOpt =~ /^-(\.\w+)?$/) {
            # allow output file type to be specified with "-o -.EXT"
            $outType = GetFileType($outOpt) if $1;
            $outfile = '-';
            $isStdout = 1;
        } else {
            $outfile = FilenameSPrintf($outOpt, $orig);
            if ($outfile eq '') {
                Warn "Error: Can't create file with zero-length name from $orig\n";
                EFile($infile);
                ++$countBadCr;
                return 0;
            }
        }
        if (not $isStdout and (($et->IsDirectory($outfile) and not $listDir) or $outfile =~ /\/$/)) {
            $outfile .= '/' unless $outfile =~ /\/$/;
            my $name = $file;
            $name =~ s/^.*\///s;    # remove directory name
            $outfile .= $name;
        } else {
            my $srcType = GetFileType($file) || '';
            $outType or $outType = GetFileType($outfile);
            if ($outType and ($srcType ne $outType or $outType eq 'ICC') and $file ne '-') {
                unless (CanCreate($outType)) {
                    my $what = $srcType ? 'other types' : 'scratch';
                    WarnOnce "Error: Can't create $outType files from $what\n";
                    EFile($infile);
                    ++$countBadCr;
                    return 0;
                }
                if ($file ne '') {
                    # restore previous new values unless done already
                    $et->RestoreNewValues() unless $restored;
                    $restored = 1;
                    # translate to this type by setting specified tags from file
                    my @setTags = @tags;
                    foreach (@exclude) {
                        push @setTags, "-$_";
                    }
                    # force some tags to be copied for certain file types
                    my %forceCopy = (
                        ICC => 'ICC_Profile',
                        VRD => 'CanonVRD',
                        DR4 => 'CanonDR4',
                    );
                    push @setTags, $forceCopy{$outType} if $forceCopy{$outType};
                    # assume "-tagsFromFile @" unless -tagsFromFile already specified
                    # (%setTags won't be empty if -tagsFromFile used)
                    if (not %setTags or (@setTags and not $setTags{'@'})) {
                        return 0 unless DoSetFromFile($et, $file, \@setTags);
                    } elsif (@setTags) {
                        # add orphaned tags to existing "-tagsFromFile @" for this file only
                        push @setTags, @{$setTags{'@'}};
                        $tagsFromSrc = \@setTags;
                    }
                    # all done with source file -- create from meta information alone
                    $file = '';
                }
            }
        }
        unless ($isStdout) {
            $outfile = NextUnusedFilename($outfile);
            if ($et->Exists($outfile) and not $doSetFileName) {
                Warn "Error: '${outfile}' already exists - $infile\n";
                EFile($infile);
                ++$countBadWr;
                return 0;
            }
        }
    } elsif ($file eq '-') {
        $isStdout = 1;
    }
    # set tags from destination file if required
    if (@dynamicFiles) {
        # restore previous values if necessary
        $et->RestoreNewValues() unless $restored;
        my ($dyFile, %setTagsIndex);
        foreach $dyFile (@dynamicFiles) {
            if (not ref $dyFile) {
                my ($fromFile, $setTags);
                if ($dyFile eq '@') {
                    $fromFile = $orig;
                    $setTags = $tagsFromSrc || $setTags{$dyFile};
                } else {
                    $fromFile = FilenameSPrintf($dyFile, $orig);
                    defined $fromFile or EFile($infile), ++$countBadWr, return 0;
                    $setTags = $setTags{$dyFile};
                }
                # do we have multiple -tagsFromFile options with this file?
                if ($setTagsList{$dyFile}) {
                    # use the tags set in the i-th occurrence
                    my $i = $setTagsIndex{$dyFile} || 0;
                    $setTagsIndex{$dyFile} = $i + 1;
                    $setTags = $setTagsList{$dyFile}[$i] if $setTagsList{$dyFile}[$i];
                }
                # set new values values from file
                return 0 unless DoSetFromFile($et, $fromFile, $setTags);
            } elsif (ref $dyFile eq 'ARRAY') {
                # a dynamic file containing a simple tag value
                my $fname = FilenameSPrintf($$dyFile[1], $orig);
                my ($buff, $rtn, $wrn);
                my $opts = $$dyFile[2];
                if (defined $fname and SlurpFile($fname, \$buff)) {
                    $verbose and print $vout "Reading $$dyFile[0] from $fname\n";
                    ($rtn, $wrn) = $et->SetNewValue($$dyFile[0], $buff, %$opts);
                    $wrn and Warn "$wrn\n";
                }
                # remove this tag if we couldn't set it properly
                $rtn or $et->SetNewValue($$dyFile[0], undef, Replace => 2,
                                         ProtectSaved => $$opts{ProtectSaved});
                next;
            } elsif (ref $dyFile eq 'SCALAR') {
                # set new values from CSV or JSON database
                my ($f, $found, $tag);
                undef $evalWarning;
                local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
                # force UTF-8 if the database was JSON
                my $old = $et->Options('Charset');
                $et->Options(Charset => 'UTF8') if $csv eq 'JSON';
                # read tags for SourceFile '*' plus the specific file
                foreach $f ('*', MyConvertFileName($et, $file)) {
                    my $csvInfo = $database{$f};
                    unless ($csvInfo) {
                        next if $f eq '*';
                        # check absolute path
                        # (punt on using ConvertFileName here, so $absPath may be a mix of encodings)
                        my $absPath = AbsPath($f);
                        next unless defined $absPath and $csvInfo = $database{$absPath};
                    }
                    $found = 1;
                    $verbose and print $vout "Setting new values from $csv database\n";
                    foreach $tag (sort keys %$csvInfo) {
                        next if $tag =~ /\b(SourceFile|Directory|FileName)$/i; # don't write these
                        my ($rtn, $wrn) = $et->SetNewValue($tag, $$csvInfo{$tag},
                                          Protected => 1, AddValue => $csvAdd,
                                          ProtectSaved => $csvSaveCount);
                        $wrn and Warn "$wrn\n" if $verbose;
                    }
                }
                $et->Options(Charset => $old) if $csv eq 'JSON';
                unless ($found) {
                    Warn("No SourceFile '${file}' in imported $csv database\n");
                    my $absPath = AbsPath($file);
                    Warn("(full path: '${absPath}')\n") if defined $absPath and $absPath ne $file;
                    return 0;
                }
            }
        }
    }
    if ($isStdout) {
        # write to STDOUT
        $outfile = \*STDOUT;
        unless ($binaryStdout) {
            binmode(STDOUT);
            $binaryStdout = 1;
        }
    } else {
        # get name of hard link if we are creating one
        $hardLink = $et->GetNewValues('HardLink');
        $symLink = $et->GetNewValues('SymLink');
        $testName = $et->GetNewValues('TestName');
        $hardLink = FilenameSPrintf($hardLink, $orig) if defined $hardLink;
        $symLink = FilenameSPrintf($symLink, $orig) if defined $symLink;
        # determine what our output file name should be
        my $newFileName = $et->GetNewValues('FileName');
        my $newDir = $et->GetNewValues('Directory');
        if (defined $newFileName and not length $newFileName) {
            Warn "Warning: New file name is empty - $ infile\n";
            undef $newFileName;
        }
        if (defined $testName) {
            my $err;
            $err = "You shouldn't write FileName or Directory with TestFile" if defined $newFileName or defined $newDir;
            $err = "The -o option shouldn't be used with TestFile" if defined $outfile;
            $err and Warn("Error: $err - $infile\n"), EFile($infile), ++$countBadWr, return 0;
            $testName = FilenameSPrintf($testName, $orig);
            $testName = Image::ExifTool::GetNewFileName($file, $testName) if $file ne '';
        }
        if (defined $newFileName or defined $newDir or ($doSetFileName and defined $outfile)) {
            if ($newFileName) {
                $newFileName = FilenameSPrintf($newFileName, $orig);
                if (defined $outfile) {
                    $outfile = Image::ExifTool::GetNewFileName($file, $outfile) if $file ne '';
                    $outfile = Image::ExifTool::GetNewFileName($outfile, $newFileName);
                } elsif ($file ne '') {
                    $outfile = Image::ExifTool::GetNewFileName($file, $newFileName);
                }
            }
            if ($newDir) {
                $newDir = FilenameSPrintf($newDir, $orig);
                $outfile = Image::ExifTool::GetNewFileName(defined $outfile ? $outfile : $file, $newDir);
            }
            $outfile = NextUnusedFilename($outfile, $infile);
            if ($et->Exists($outfile)) {
                if ($infile eq $outfile) {
                    undef $outfile;     # not changing the file name after all
                # (allow for case-insensitive filesystems)
                } elsif ($et->IsSameFile($infile, $outfile)) {
                    $sameFile = $outfile;   # same file, but the name has a different case
                } else {
                    Warn "Error: '${outfile}' already exists - $infile\n";
                    EFile($infile);
                    ++$countBadWr;
                    return 0;
                }
            }
        }
        if (defined $outfile) {
            $verbose and print $vout "'${infile}' --> '${outfile}'\n";
            # create output directory if necessary
            CreateDirectory($outfile);
            # set temporary file (automatically erased on abnormal exit)
            $tmpFile = $outfile if defined $outOpt;
        }
        unless (defined $tmpFile) {
            # count the number of tags and pseudo-tags we are writing
            my ($numSet, $numPseudo) = $et->CountNewValues();
            if ($numSet != $numPseudo and $et->IsDirectory($file)) {
                print $vout "Can't write real tags to a directory - $infile\n" if defined $verbose;
                $numSet = $numPseudo;
            }
            if ($et->Exists($file)) {
                unless ($numSet) {
                    # no need to write if no tags set
                    print $vout "Nothing changed in $file\n" if defined $verbose;
                    EFile($infile, 1);
                    ++$countSameWr;
                    return 1;
                }
            } elsif (CanCreate($file)) {
                if ($numSet == $numPseudo) {
                    # no need to write if no real tags
                    Warn("Error: Nothing to write - $file\n");
                    EFile($infile, 1);
                    ++$countBadWr;
                    return 0;
                }
                unless (defined $outfile) {
                    # create file from scratch
                    $outfile = $file;
                    $file = '';
                }
            } else {
                # file doesn't exist, and we can't create it
                Warn "Error: File not found - $file\n";
                EFile($infile);
                FileNotFound($file);
                ++$countBadWr;
                return 0;
            }
            # quickly rename file and/or set file date if this is all we are doing
            if ($numSet == $numPseudo) {
                my ($r0, $r1, $r2, $r3) = (0, 0, 0, 0);
                if (defined $outfile) {
                    $r0 = $et->SetFileName($file, $outfile);
                    $file = $$et{NewName} if $r0 > 0;   # continue with new name if changed
                }
                unless ($r0 < 0) {
                    $r1 = $et->SetFileModifyDate($file,undef,'FileCreateDate');
                    $r2 = $et->SetFileModifyDate($file);
                    $r3 = $et->SetSystemTags($file);
                }
                if ($r0 > 0 or $r1 > 0 or $r2 > 0 or $r3 > 0) {
                    ++$countGoodWr;
                } elsif ($r0 < 0 or $r1 < 0 or $r2 < 0 or $r3 < 0) {
                    EFile($infile);
                    ++$countBadWr;
                    return 0;
                } else {
                    EFile($infile, 1);
                    ++$countSameWr;
                }
                if (defined $hardLink or defined $symLink or defined $testName) {
                    DoHardLink($et, $file, $hardLink, $symLink, $testName);
                }
                return 1;
            }
            if (not defined $outfile or defined $sameFile) {
                # write to a truly temporary file
                $outfile = "${file}_exiftool_tmp";
                if ($et->Exists($outfile)) {
                    Warn("Error: Temporary file already exists: $outfile\n");
                    EFile($infile);
                    ++$countBadWr;
                    return 0;
                }
                $isTemporary = 1;
            }
            # new output file is temporary until we know it has been written properly
            $tmpFile = $outfile;
        }
    }
    # rewrite the file
    my $success = $et->WriteInfo(Infile($file), $outfile, $outType);

    # create hard link if specified
    if ($success and (defined $hardLink or defined $symLink or defined $testName)) {
        my $src = defined $outfile ? $outfile : $file;
        DoHardLink($et, $src, $hardLink, $symLink, $testName);
    }

    # get file time if preserving it
    my ($aTime, $mTime, $cTime, $doPreserve);
    $doPreserve = $preserveTime unless $file eq '';
    if ($doPreserve and $success) {
        ($aTime, $mTime, $cTime) = $et->GetFileTime($file);
        # don't override date/time values written by the user
        undef $cTime if $$et{WRITTEN}{FileCreateDate};
        if ($$et{WRITTEN}{FileModifyDate} or $doPreserve == 2) {
            if (defined $cTime) {
                undef $aTime;       # only preserve FileCreateDate
                undef $mTime;
            } else {
                undef $doPreserve;  # (nothing to preserve)
            }
        }
    }

    if ($success == 1) {
        # preserve the original file times
        if (defined $tmpFile) {
            if ($et->Exists($file)) {
                $et->SetFileTime($tmpFile, $aTime, $mTime, $cTime) if $doPreserve;
                if ($isTemporary) {
                    # preserve original file attributes if possible
                    $et->CopyFileAttrs($file, $outfile);
                    # move original out of the way
                    my $original = "${file}_original";
                    if (not $overwriteOrig and not $et->Exists($original)) {
                        # rename the file and check again to be sure the file doesn't exist
                        # (in case, say, the filesystem truncated the file extension)
                        if (not $et->Rename($file, $original) or $et->Exists($file)) {
                            Error "Error renaming $file\n";
                            return 0;
                        }
                    }
                    my $dstFile = defined $sameFile ? $sameFile : $file;
                    if ($overwriteOrig > 1) {
                        # copy temporary file over top of original to preserve attributes
                        my ($err, $buff);
                        my $newFile = $tmpFile;
                        $et->Open(\*NEW_FILE, $newFile) or Error("Error opening $newFile\n"), return 0;
                        binmode(NEW_FILE);

                        #..........................................................
                        # temporarily disable CTRL-C during this critical operation
                        $critical = 1;
                        undef $tmpFile;     # handle deletion of temporary file ourself
                        if ($et->Open(\*ORIG_FILE, $file, '>')) {
                            binmode(ORIG_FILE);
                            while (read(NEW_FILE, $buff, 65536)) {
                                print ORIG_FILE $buff or $err = 1;
                            }
                            close(NEW_FILE);
                            close(ORIG_FILE) or $err = 1;
                            if ($err) {
                                Warn "Couldn't overwrite in place - $file\n";
                                unless ($et->Rename($newFile, $file) or
                                    ($et->Unlink($file) and $et->Rename($newFile, $file)))
                                {
                                    Error("Error renaming $newFile to $file\n");
                                    undef $critical;
                                    SigInt() if $interrupted;
                                    return 0;
                                }
                            } else {
                                $et->SetFileModifyDate($file, $cTime, 'FileCreateDate', 1);
                                $et->SetFileModifyDate($file, $mTime, 'FileModifyDate', 1);
                                $et->Unlink($newFile);
                                if ($doPreserve) {
                                    $et->SetFileTime($file, $aTime, $mTime, $cTime);
                                    # save time to set it later again to patch OS X 10.6 bug
                                    $preserveTime{$file} = [ $aTime, $mTime, $cTime ];
                                }
                            }
                            ++$countGoodWr;
                        } else {
                            close(NEW_FILE);
                            Warn "Error opening $file for writing\n";
                            EFile($infile);
                            $et->Unlink($newFile);
                            ++$countBadWr;
                        }
                        undef $critical;            # end critical section
                        SigInt() if $interrupted;   # issue delayed SIGINT if necessary
                        #..........................................................

                    # simply rename temporary file to replace original
                    # (if we didn't already rename it to add "_original")
                    } elsif ($et->Rename($tmpFile, $dstFile)) {
                        ++$countGoodWr;
                    } else {
                        my $newFile = $tmpFile;
                        undef $tmpFile; # (avoid deleting file if we get interrupted)
                        # unlink may fail if already renamed or no permission
                        if (not $et->Unlink($file)) {
                            Warn "Error renaming temporary file to $dstFile\n";
                            EFile($infile);
                            $et->Unlink($newFile);
                            ++$countBadWr;
                        # try renaming again now that the target has been deleted
                        } elsif (not $et->Rename($newFile, $dstFile)) {
                            Warn "Error renaming temporary file to $dstFile\n";
                            EFile($infile);
                            # (don't delete tmp file now because it is all we have left)
                            ++$countBadWr;
                        } else {
                            ++$countGoodWr;
                        }
                    }
                } elsif ($overwriteOrig) {
                    # erase original file
                    $et->Unlink($file) or Warn "Error erasing original $file\n";
                    ++$countGoodWr;
                } else {
                    ++$countGoodCr;
                }
            } else {
                # this file was created from scratch, not edited
                ++$countGoodCr;
            }
        } else {
            ++$countGoodWr;
        }
    } elsif ($success) {
        EFile($infile, 1);
        if ($isTemporary) {
            # just erase the temporary file since no changes were made
            $et->Unlink($tmpFile);
            ++$countSameWr;
        } else {
            $et->SetFileTime($outfile, $aTime, $mTime, $cTime) if $doPreserve;
            if ($overwriteOrig) {
                $et->Unlink($file) or Warn "Error erasing original $file\n";
            }
            ++$countCopyWr;
        }
        print $vout "Nothing changed in $file\n" if defined $verbose;
    } else {
        EFile($infile);
        $et->Unlink($tmpFile) if defined $tmpFile;
        ++$countBadWr;
    }
    undef $tmpFile;
    return $success;
}

#------------------------------------------------------------------------------
# Make hard link and handle TestName if specified
# Inputs: 0) ExifTool ref, 1) source file name, 2) HardLink name,
#         3) SymLink name, 4) TestFile name
sub DoHardLink($$$$$)
{
    my ($et, $src, $hardLink, $symLink, $testName) = @_;
    if (defined $hardLink) {
        $hardLink = NextUnusedFilename($hardLink);
        if ($et->SetFileName($src, $hardLink, 'Link') > 0) {
            $countLink{Hard} = ($countLink{Hard} || 0) + 1;
        } else {
            $countLink{BadHard} = ($countLink{BadHard} || 0) + 1;
        }
    }
    if (defined $symLink) {
        $symLink = NextUnusedFilename($symLink);
        if ($et->SetFileName($src, $symLink, 'SymLink') > 0) {
            $countLink{Sym} = ($countLink{Sym} || 0) + 1;
        } else {
            $countLink{BadSym} = ($countLink{BadSym} || 0) + 1;
        }
    }
    if (defined $testName) {
        $testName = NextUnusedFilename($testName, $src);
        if ($usedFileName{$testName}) {
            $et->Warn("File '${testName}' would exist");
        } elsif ($et->SetFileName($src, $testName, 'Test', $usedFileName{$testName}) == 1) {
            $usedFileName{$testName} = 1;
            $usedFileName{$src} = 0;
        }
    }
}

#------------------------------------------------------------------------------
# Clean string for XML (also removes invalid control chars and malformed UTF-8)
# Inputs: 0) string ref
# Returns: nothing, but input string is escaped
sub CleanXML($)
{
    my $strPt = shift;
    # translate control characters that are invalid in XML
    $$strPt =~ tr/\0-\x08\x0b\x0c\x0e-\x1f/./;
    # fix malformed UTF-8 characters
    Image::ExifTool::XMP::FixUTF8($strPt) unless $altEnc;
    # escape necessary characters for XML
    $$strPt = Image::ExifTool::XMP::EscapeXML($$strPt);
}

#------------------------------------------------------------------------------
# Encode string for XML
# Inputs: 0) string ref
# Returns: encoding used (and input string is translated)
sub EncodeXML($)
{
    my $strPt = shift;
    if ($$strPt =~ /[\0-\x08\x0b\x0c\x0e-\x1f]/ or
        (not $altEnc and Image::ExifTool::XMP::IsUTF8($strPt) < 0))
    {
        # encode binary data and non-UTF8 with special characters as base64
        $$strPt = Image::ExifTool::XMP::EncodeBase64($$strPt);
        # #ATV = Alexander Vonk, private communication
        return 'http://www.w3.org/2001/XMLSchema#base64Binary'; #ATV
    } elsif ($escapeHTML) {
        $$strPt = Image::ExifTool::HTML::EscapeHTML($$strPt, $altEnc);
    } else {
        $$strPt = Image::ExifTool::XMP::EscapeXML($$strPt);
    }
    return '';  # not encoded
}

#------------------------------------------------------------------------------
# Format value for XML output
# Inputs: 0) value, 1) indentation, 2) group
# Returns: formatted value
sub FormatXML($$$)
{
    local $_;
    my ($val, $ind, $grp) = @_;
    my $gt = '>';
    if (ref $val eq 'ARRAY') {
        # convert ARRAY into an rdf:Bag
        my $val2 = "\n$ind <rdf:Bag>";
        foreach (@$val) {
            $val2 .= "\n$ind  <rdf:li" . FormatXML($_, "$ind  ", $grp) . "</rdf:li>";
        }
        $val = "$val2\n$ind </rdf:Bag>\n$ind";
    } elsif (ref $val eq 'HASH') {
        $gt = " rdf:parseType='Resource'>";
        my $val2 = '';
        my @keys = $$val{_ordered_keys_} ? @{$$val{_ordered_keys_}} : sort keys %$val;
        foreach (@keys) {
            # (some variable-namespace XML structure fields may have a different group)
            my $tok = /:/ ? $_ : ($grp . ':' . $_);
            $val2 .= "\n$ind <$tok" . FormatXML($$val{$_}, "$ind ", $grp) . "</$tok>";
        }
        $val = "$val2\n$ind";
    } else {
        # (note: SCALAR reference should have already been converted)
        my $enc = EncodeXML(\$val);
        $gt = " rdf:datatype='${enc}'>\n" if $enc; #ATV
    }
    return $gt . $val;
}

#------------------------------------------------------------------------------
# Escape string for JSON or PHP
# Inputs: 0) string, 1) flag to force numbers to be quoted too
# Returns: Escaped string (quoted if necessary)
sub EscapeJSON($;$)
{
    my ($str, $quote) = @_;
    unless ($quote) {
        # JSON boolean (true or false)
        return lc($str) if $str =~ /^(true|false)$/i and $json < 2;
        # JSON/PHP number (see json.org for numerical format)
        # return $str if $str =~ /^-?(\d|[1-9]\d+)(\.\d+)?(e[-+]?\d+)?$/i;
        # (these big numbers caused problems for some JSON parsers, so be more conservative)
        return $str if $str =~ /^-?(\d|[1-9]\d{1,14})(\.\d{1,16})?(e[-+]?\d{1,3})?$/i;
    }
    # encode JSON string in base64 if necessary
    if ($json < 2 and defined $binaryOutput and Image::ExifTool::XMP::IsUTF8(\$str) < 0) {
        return '"base64:' . Image::ExifTool::XMP::EncodeBase64($str, 1) . '"';
    }
    # escape special characters
    $str =~ s/(["\t\n\r\\])/\\$jsonChar{$1}/sg;
    if ($json < 2) { # JSON
        $str =~ tr/\0//d;   # remove all nulls
        # escape other control characters with \u
        $str =~ s/([\0-\x1f])/sprintf("\\u%.4X",ord $1)/sge;
        # JSON strings must be valid UTF8
        Image::ExifTool::XMP::FixUTF8(\$str) unless $altEnc;
    } else { # PHP
        $str =~ s/\0+$// unless $isBinary;  # remove trailing nulls unless binary
        # must escape "$" too for PHP
        $str =~ s/\$/\\\$/sg;
        # escape other control characters with \x
        $str =~ s/([\0-\x1f])/sprintf("\\x%.2X",ord $1)/sge;
    }
    return '"' . $str . '"';    # return the quoted string
}

#------------------------------------------------------------------------------
# Print JSON or PHP value
# Inputs: 0) file reference, 1) value, 2) indentation
sub FormatJSON($$$)
{
    local $_;
    my ($fp, $val, $ind) = @_;
    my $comma;
    if (not ref $val) {
        print $fp EscapeJSON($val);
    } elsif (ref $val eq 'ARRAY') {
        if ($joinLists and not ref $$val[0]) {
            print $fp EscapeJSON(join $listSep, @$val);
        } else {
            my ($bra, $ket) = $json == 1 ? ('[',']') : ('Array(',')');
            print $fp $bra;
            foreach (@$val) {
                print $fp ',' if $comma;
                FormatJSON($fp, $_, $ind);
                $comma = 1,
            }
            print $fp $ket,
        }
    } elsif (ref $val eq 'HASH') {
        my ($bra, $ket, $sep) = $json == 1 ? ('{','}',':') : ('Array(',')',' =>');
        print $fp $bra;
        my @keys = $$val{_ordered_keys_} ? @{$$val{_ordered_keys_}} : sort keys %$val;
        foreach (@keys) {
            print $fp ',' if $comma;
            my $key = EscapeJSON($_, 1);
            print $fp qq(\n$ind  $key$sep );
            # hack to force decimal id's to be printed as strings with -H
            if ($showTagID and $_ eq 'id' and $showTagID eq 'H' and $$val{$_} =~ /^\d+\.\d+$/) {
                print $fp qq{"$$val{$_}"};
            } else {
                FormatJSON($fp, $$val{$_}, "$ind  ");
            }
            $comma = 1,
        }
        print $fp "\n$ind$ket",
    } else {
        # (note: SCALAR reference should have already been converted)
        print $fp '"<err>"';
    }
}

#------------------------------------------------------------------------------
# Format value for CSV file
# Inputs: value
# Returns: value quoted if necessary
sub FormatCSV($)
{
    my $val = shift;
    # check for valid encoding if the Charset option was used
    if ($setCharset and ($val =~ /[^\x09\x0a\x0d\x20-\x7e\x80-\xff]/ or
        ($setCharset eq 'UTF8' and Image::ExifTool::XMP::IsUTF8(\$val) < 0)))
    {
        $val = 'base64:' . Image::ExifTool::XMP::EncodeBase64($val, 1);
    }
    # currently, there is a chance that the value may contain NULL characters unless
    # the -b option is used to encode as Base64.  It is unclear whether or not this
    # is valid CSV, but some readers may not like it.  (If this becomes a problem,
    # in the future values may need to be truncated at the first NULL character.)
    $val = qq{"$val"} if $val =~ s/"/""/g or $val =~ /(^\s+|\s+$)/ or $val =~ /[\n\r]|\Q$csvDelim/;
    return $val;
}

#------------------------------------------------------------------------------
# Print accumulated CSV information
sub PrintCSV()
{
    my ($file, $lcTag, @tags);

    @csvTags or @csvTags = sort keys %csvTags;
    # make a list of tags actually found
    foreach $lcTag (@csvTags) {
        push @tags, FormatCSV($csvTags{$lcTag}) if $csvTags{$lcTag};
    }
    print join($csvDelim, 'SourceFile', @tags), "\n";
    my $empty = defined($forcePrint) ? $forcePrint : '';
    foreach $file (@csvFiles) {
        my @vals = (FormatCSV($file)); # start with full file name
        my $csvInfo = $database{$file};
        foreach $lcTag (@csvTags) {
            next unless $csvTags{$lcTag};
            my $val = $$csvInfo{$lcTag};
            defined $val or push(@vals,$empty), next;
            push @vals, FormatCSV($val);
        }
        print join($csvDelim, @vals), "\n";
    }
}

#------------------------------------------------------------------------------
# Add tag groups from structure fields to a list
# Inputs: 0) tag value, 1) parent group, 2) group hash ref, 3) group list ref
sub AddGroups($$$$)
{
    my ($val, $grp, $groupHash, $groupList) = @_;
    my ($key, $val2);
    if (ref $val eq 'HASH') {
        foreach $key (sort keys %$val) {
            if ($key =~ /(.*?):/ and not $$groupHash{$1}) {
                $$groupHash{$1} = $grp;
                push @$groupList, $1;
            }
            AddGroups($$val{$key}, $grp, $groupHash, $groupList) if ref $$val{$key};
        }
    } elsif (ref $val eq 'ARRAY') {
        foreach $val2 (@$val) {
            AddGroups($val2, $grp, $groupHash, $groupList) if ref $val2;
        }
    }
}

#------------------------------------------------------------------------------
# Convert binary data (SCALAR references) for printing
# Inputs: 0) object reference
# Returns: converted object, or undef if we don't want binary objects
sub ConvertBinary($)
{
    my $obj = shift;
    my ($key, $val);
    if (ref $obj eq 'HASH') {
        foreach $key (keys %$obj) {
            next unless ref $$obj{$key};
            $$obj{$key} = ConvertBinary($$obj{$key});
            return undef unless defined $$obj{$key};
        }
    } elsif (ref $obj eq 'ARRAY') {
        foreach $val (@$obj) {
            next unless ref $val;
            $val = ConvertBinary($val);
            return undef unless defined $val;
        }
    } elsif (ref $obj eq 'SCALAR') {
        return undef if $noBinary;
        # (binaryOutput flag is set to 0 for binary mode of XML/PHP/JSON output formats)
        if (defined $binaryOutput) {
            $obj = $$obj;
            # encode in base64 if necessary (0xf7 allows for up to 21-bit UTF-8 code space)
            if ($json == 1 and ($obj =~ /[^\x09\x0a\x0d\x20-\x7e\x80-\xf7]/ or
                                Image::ExifTool::XMP::IsUTF8(\$obj) < 0))
            {
                $obj = 'base64:' . Image::ExifTool::XMP::EncodeBase64($obj, 1);
            }
        } else {
            # (-b is not valid for HTML output)
            my $bOpt = $html ? '' : ', use -b option to extract';
            if ($$obj =~ /^Binary data \d+ bytes$/) {
                $obj = "($$obj$bOpt)";
            } else {
                $obj = '(Binary data ' . length($$obj) . " bytes$bOpt)";
            }
        }
    }
    return $obj;
}

#------------------------------------------------------------------------------
# Compare two tag values to see if they are equal
# Inputs: 0) value1, 1) value2
# Returns: true if they are equal
sub IsEqual($$)
{
    return 1 if ref $_[0] eq 'SCALAR' or $_[0] eq $_[1];
    return 0 if ref $_[0] ne 'ARRAY' or ref $_[1] ne 'ARRAY' or
                @{$_[0]} ne @{$_[1]};
    # test all elements of an array
    my $i = 0;
    for ($i=0; $i<scalar(@{$_[0]}); ++$i) {
        return 0 if $_[0][$i] ne $_[1][$i];
    }
    return 1;
}

#------------------------------------------------------------------------------
# Add tag list for copying tags from specified file
# Inputs: 0) set tags file name (or FMT), 1) options for SetNewValuesFromFile()
# Returns: nothing
# Notes: Uses global variables: %setTags, %setTagsList, @newValues, $saveCount
sub AddSetTagsFile($;$)
{
    my ($setFile, $opts) = @_;
    if ($setTags{$setFile}) {
        # move these tags aside and make a new list for the next invocation of this file
        $setTagsList{$setFile} or $setTagsList{$setFile} = [ ];
        push @{$setTagsList{$setFile}}, $setTags{$setFile};
    }
    $setTags{$setFile} = [];    # create list for tags to copy from this file
    # insert marker to save new values now (necessary even if this is not a dynamic
    # file in case the same file is source'd multiple times in a single command)
    push @newValues, { SaveCount => ++$saveCount }, "TagsFromFile=$setFile";
    # add option to protect the tags which are assigned after this
    # (this is the mechanism by which the command-line order-of-operations is preserved)
    $opts or $opts = { };
    $$opts{ProtectSaved} = $saveCount;
    push @{$setTags{$setFile}}, $opts;
}

#------------------------------------------------------------------------------
# Get input file name or reference for calls to the ExifTool API
# Inputs: 0) file name ('-' for STDIN), 1) flag to buffer STDIN
# Returns: file name, or RAF reference for buffering STDIN
sub Infile($;$)
{
    my ($file, $bufferStdin) = @_;
    if ($file eq '-' and ($bufferStdin or $rafStdin)) {
        if ($rafStdin) {
            $rafStdin->Seek(0); # rewind
        } elsif (open RAF_STDIN, '-') {
            $rafStdin = new File::RandomAccess(\*RAF_STDIN);
            $rafStdin->BinMode();
        }
        return $rafStdin if $rafStdin;
    }
    return $file;
}

#------------------------------------------------------------------------------
# Set new values from file
# Inputs: 0) exiftool ref, 1) filename, 2) reference to list of values to set
# Returns: 0 on error (and increments $countBadWr)
sub DoSetFromFile($$$)
{
    local $_;
    my ($et, $file, $setTags) = @_;
    $verbose and print $vout "Setting new values from $file\n";
    my $info = $et->SetNewValuesFromFile(Infile($file,1), @$setTags);
    my $numSet = scalar(keys %$info);
    if ($$info{Error}) {
        # delete all error and warning tags
        my @warns = grep /^(Error|Warning)\b/, keys %$info;
        $numSet -= scalar(@warns);
        # issue a warning for the main error only if we were able to set some tags
        if (keys(%$info) > @warns) {
            my $err = $$info{Error};
            delete $$info{$_} foreach @warns;
            $$info{Warning} = $err;
        }
    } elsif ($$info{Warning}) {
        my $warns = 1;
        ++$warns while $$info{"Warning ($warns)"};
        $numSet -= $warns;
    }
    PrintErrors($et, $info, $file) and EFile($file), ++$countBadWr, return 0;
    Warn "Warning: No writable tags set from $file\n" unless $numSet;
    return 1;
}

#------------------------------------------------------------------------------
# Translate backslashes to forward slashes in filename if necessary
# Inputs: 0) Filename
# Returns: nothing, but changes filename if necessary
sub CleanFilename($)
{
    $_[0] =~ tr/\\/\// if $hasBackslash{$^O};
}

#------------------------------------------------------------------------------
# Check for valid UTF-8 of a file name
# Inputs: 0) string, 1) original encoding
# Returns: 0=plain ASCII, 1=valid UTF-8, -1=invalid UTF-8 (and print warning)
sub CheckUTF8($$)
{
    my ($file, $enc) = @_;
    my $isUTF8 = 0;
    if ($file =~ /[\x80-\xff]/) {
        require Image::ExifTool::XMP;
        $isUTF8 = Image::ExifTool::XMP::IsUTF8(\$file);
        if ($isUTF8 < 0) {
            if ($enc) {
                Warn("Invalid filename encoding for $file\n");
            } elsif (not defined $enc) {
                WarnOnce(qq{FileName encoding not specified.  Use "-charset FileName=CHARSET"\n});
            }
        }
    }
    return $isUTF8;
}

#------------------------------------------------------------------------------
# Set window title
# Inputs: title string or '' to reset title
sub SetWindowTitle($)
{
    my $title = shift;
    if ($curTitle ne $title) {
        $curTitle = $title;
        if ($^O eq 'MSWin32') {
            $title =~ s/([&\/\?:|"<>])/^$1/g;   # escape special chars
            eval { system qq{title $title} };
        } else {
            # (this only works for XTerm terminals, and STDERR must go to the console)
            printf STDERR "\033]0;%s\007", $title;
        }
    }
}

#------------------------------------------------------------------------------
# Process files in our @files list
# Inputs: 0) ExifTool ref, 1) list ref to just return full file names
sub ProcessFiles($;$)
{
    my ($et, $list) = @_;
    my $enc = $et->Options('CharsetFileName');
    my $file;
    foreach $file (@files) {
        $et->Options(CharsetFileName => 'UTF8') if $utf8FileName{$file};
        if (defined $progressMax) {
            ++$progressCount;
            $progStr = " [$progressCount/$progressMax]" if $progress;
        }
        if ($et->IsDirectory($file) and not $listDir) {
            $multiFile = $validFile = 1;
            ScanDir($et, $file, $list);
        } elsif ($filterFlag and not AcceptFile($file)) {
            if ($et->Exists($file)) {
                $filtered = 1;
                $verbose and print $vout "-------- $file (wrong extension)$progStr\n";
            } else {
                Warn "Error: File not found - $file\n";
                FileNotFound($file);
                $rtnVal = 1;
            }
        } else {
            $validFile = 1;
            if ($list) {
                push(@$list, $file);
            } else {
                if (%endDir) {
                    my ($d, $f) = Image::ExifTool::SplitFileName($file);
                    next if $endDir{$d};
                }
                GetImageInfo($et, $file);
                $end and Warn("End called - $file\n");
                if ($endDir) {
                    Warn("EndDir called - $file\n");
                    my ($d, $f) = Image::ExifTool::SplitFileName($file);
                    $endDir{$d} = 1;
                    undef $endDir;
                }
            }
        }
        $et->Options(CharsetFileName => $enc) if $utf8FileName{$file};
        last if $end;
    }
}

#------------------------------------------------------------------------------
# Scan directory for image files
# Inputs: 0) ExifTool ref, 1) directory name, 2) list ref to return file names
sub ScanDir($$;$)
{
    local $_;
    my ($et, $dir, $list) = @_;
    my (@fileList, $done, $file, $utf8Name, $winSurrogate, $endThisDir);
    my $enc = $et->Options('CharsetFileName');
    # recode as UTF-8 if necessary
    if ($enc) {
        unless ($enc eq 'UTF8') {
            $dir = $et->Decode($dir, $enc, undef, 'UTF8');
            $et->Options(CharsetFileName => 'UTF8');    # now using UTF8
        }
        $utf8Name = 1;
    }
    return if $ignore{$dir};
    my $oldBase = $seqFileBase;
    $seqFileBase = $seqFileNum;
    # use Win32::FindFile on Windows if available
    # (ReadDir will croak if there is a wildcard, so check for this)
    if ($^O eq 'MSWin32' and $dir !~ /[*?]/) {
        undef $evalWarning;
        local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };;
        if (CheckUTF8($dir, $enc) >= 0) {
            if (eval { require Win32::FindFile }) {
                eval {
                    @fileList = Win32::FindFile::ReadDir($dir);
                    $_ = $_->cFileName foreach @fileList;
                };
                $@ and $evalWarning = $@;
                if ($evalWarning) {
                    chomp $evalWarning;
                    $evalWarning =~ s/ at .*//s;
                    Warn "Warning: [Win32::FindFile] $evalWarning - $dir\n";
                    $winSurrogate = 1 if $evalWarning =~ /surrogate/;
                } else {
                    $et->Options(CharsetFileName => 'UTF8');    # now using UTF8
                    $utf8Name = 1;  # ReadDir returns UTF-8 file names
                    $done = 1;
                }
            } else {
                $done = 0;
            }
        }
    }
    unless ($done) {
        # use standard perl library routines to read directory
        unless (opendir(DIR_HANDLE, $dir)) {
            Warn("Error opening directory $dir\n");
            $seqFileBase = $oldBase + ($seqFileNum - $seqFileBase);
            return;
        }
        @fileList = readdir(DIR_HANDLE);
        closedir(DIR_HANDLE);
        if (defined $done) {
            # issue warning if some names would have required Win32::FindFile
            foreach $file ($dir, @fileList) {
                next unless $file =~ /[\?\x80-\xff]/;
                WarnOnce("Install Win32::FindFile to support Windows Unicode file names in directories\n");
                last;
            }
        }
    }
    $dir =~ /\/$/ or $dir .= '/';   # make sure directory name ends with '/'
    foreach $file (@fileList) {
        my $path = "$dir$file";
        if ($et->IsDirectory($path)) {
            next unless $recurse;
            # ignore directories starting with "." by default
            next if $file =~ /^\./ and ($recurse == 1 or $file eq '.' or $file eq '..');
            next if $ignore{$file} or ($ignore{SYMLINKS} and -l $path);
            ScanDir($et, $path, $list);
            last if $end;
            next;
        }
        next if $endThisDir;
        next if $ignoreHidden and $file =~ /^\./;   # ignore hidden files if specified
        # apply rules from -ext options
        my $accepted;
        if ($filterFlag) {
            $accepted = AcceptFile($file) or next;
            # must be specifically accepted to bypass selection logic
            $accepted &= 0x01;
        }
        unless ($accepted) {
            # read/write this file if it is a supported type
            if ($scanWritable) {
                if ($scanWritable eq '1') {
                    next unless CanWrite($file);
                } else {
                    my $type = GetFileType($file);
                    next unless defined $type and $type eq $scanWritable;
                }
            } elsif (not GetFileType($file)) {
                next unless $doUnzip;
                next unless $file =~ /\.(gz|bz2)$/i;
            }
        }
        # Windows patch to avoid replacing filename containing Unicode surrogate with 8.3 name
        if ($winSurrogate and $isWriting and
            (not $overwriteOrig or $overwriteOrig != 2) and
            not $doSetFileName and $file =~ /~/)   # (8.3 name will contain a tilde)
        {
            Warn("Not writing $path\n");
            WarnOnce("Use -overwrite_original_in_place to write files with Unicode surrogate characters\n");
            EFile($file);
            ++$countBad;
            next;
        }
        $utf8FileName{$path} = 1 if $utf8Name;
        if ($list) {
            push(@$list, $path);
        } else {
            GetImageInfo($et, $path);
            if ($end) {
                Warn("End called - $file\n");
                last;
            }
            if ($endDir) {
                $path =~ s(/$)();
                Warn("EndDir called - $path\n");
                $endDir{$path} = 1;
                $endThisDir = 1;
                undef $endDir;
            }
        }
    }
    ++$countDir;
    $et->Options(CharsetFileName => $enc);  # restore original setting
    # update sequential file base for parent directory
    $seqFileBase = $oldBase + ($seqFileNum - $seqFileBase);
}

#------------------------------------------------------------------------------
# Find files with wildcard expression on Windows
# Inputs: 0) ExifTool ref, 1) file name with wildcards
# Returns: list of matching file names
# Notes:
# 1) Win32::FindFile must already be loaded
# 2) Sets flag in %utf8FileName for each file found
sub FindFileWindows($$)
{
    my ($et, $wildfile) = @_;

    # recode file name as UTF-8 if necessary
    my $enc = $et->Options('CharsetFileName');
    $wildfile = $et->Decode($wildfile, $enc, undef, 'UTF8') if $enc and $enc ne 'UTF8';
    $wildfile =~ tr/\\/\//; # use forward slashes
    my ($dir, $wildname) = ($wildfile =~ m{(.*/)(.*)}) ? ($1, $2) : ('', $wildfile);
    if ($dir =~ /[*?]/) {
        Warn "Wildcards don't work in the directory specification\n";
        return ();
    }
    CheckUTF8($wildfile, $enc) >= 0 or return ();
    undef $evalWarning;
    local $SIG{'__WARN__'} = sub { $evalWarning = $_[0] };
    my @files;
    eval {
        my @names = Win32::FindFile::FindFile($wildfile) or return;
        # (apparently this isn't always sorted, so do a case-insensitive sort here)
        @names = sort { uc($a) cmp uc($b) } @names;
        my ($rname, $nm);
        # replace "\?" with ".", and "\*" with ".*" for regular expression
        ($rname = quotemeta $wildname) =~ s/\\\?/./g;
        $rname =~ s/\\\*/.*/g;
        foreach $nm (@names) {
            $nm = $nm->cFileName;
            # make sure that FindFile behaves
            # (otherwise "*.jpg" matches things like "a.jpg_original"!)
            next unless $nm =~ /^$rname$/i;
            next if $nm eq '.' or $nm eq '..';  # don't match "." and ".."
            my $file = "$dir$nm";       # add back directory name
            push @files, $file;
            $utf8FileName{$file} = 1;   # flag this file name as UTF-8 encoded
        }
    };
    $@ and $evalWarning = $@;
    if ($evalWarning) {
        chomp $evalWarning;
        $evalWarning =~ s/ at .*//s;
        Warn "Error: [Win32::FindFile] $evalWarning - $wildfile\n";
        undef @files;
        EFile($wildfile);
        ++$countBad;
    }
    return @files;
}

#------------------------------------------------------------------------------
# Handle missing file on the command line
# Inputs: 0) file name
sub FileNotFound($)
{
    my $file = shift;
    if ($file =~ /^(DIR|FILE)$/) {
        my $type = { DIR => 'directory', FILE => 'file' }->{$file};
        Warn qq{You were meant to enter any valid $type name, not "$file" literally.\n};
    }
}

#------------------------------------------------------------------------------
# Patch for OS X 10.6 to preserve file modify date
# (this probably isn't a 100% fix, but it may solve a majority of the cases)
sub PreserveTime()
{
    local $_;
    $mt->SetFileTime($_, @{$preserveTime{$_}}) foreach keys %preserveTime;
    undef %preserveTime;
}

#------------------------------------------------------------------------------
# Return absolute path for a file
# Inputs: 0) file name
# Returns: absolute path string, or undef if path could not be determined
# Note: Warnings should be suppressed when calling this routine
sub AbsPath($)
{
    my $file = shift;
    my $path;
    if (defined $file and eval { require Cwd }) {
        $path = eval { Cwd::abs_path($file) };
        # make the delimiters and case consistent
        # (abs_path is very inconsistent about what it returns in Windows)
        if (defined $path and $hasBackslash{$^O}) {
            $path =~ tr/\\/\//;
            $path = lc $path;
        }
    }
    return $path;
}

#------------------------------------------------------------------------------
# Convert file name to ExifTool Charset
# Inputs: 0) ExifTool ref, 1) file name in CharsetFileName
# Returns: file name in ExifTool Charset
sub MyConvertFileName($$)
{
    my ($et, $file) = @_;
    my $enc = $et->Options('CharsetFileName');
    $et->Options(CharsetFileName => 'UTF8') if $utf8FileName{$file};
    my $convFile = $et->ConvertFileName($file);
    $et->Options(CharsetFileName => $enc) if $utf8FileName{$file};
    return $convFile;
}

#------------------------------------------------------------------------------
# Add print format entry
# Inputs: 0) expression string
sub AddPrintFormat($)
{
    my $expr = shift;
    my $type;
    if ($expr =~ /^#/) {
        $expr =~ s/^#\[(HEAD|SECT|IF|BODY|ENDS|TAIL)\]// or return; # ignore comments
        $type = $1;
    } else {
        $type = 'BODY';
    }
    $printFmt{$type} or $printFmt{$type} = [ ];
    push @{$printFmt{$type}}, $expr;
    # add to list of requested tags
    push @requestTags, $expr =~ /\$\{?((?:[-\w]+:)*[-\w?*]+)/g;
}

#------------------------------------------------------------------------------
# Get suggested file extension based on tag value for binary output
# Inputs: 0) ExifTool ref, 1) data ref, 2) tag name
# Returns: file extension (lower case), or 'dat' if unknown
sub SuggestedExtension($$$)
{
    my ($et, $valPt, $tag) = @_;
    my $ext;
    if (not $binaryOutput) {
        $ext = 'txt';
    } elsif ($$valPt =~ /^\xff\xd8\xff/) {
        $ext = 'jpg';
    } elsif ($$valPt =~ /^(\0\0\0\x0cjP(  |\x1a\x1a)\x0d\x0a\x87\x0a|\xff\x4f\xff\x51\0)/) {
        $ext = 'jp2';
    } elsif ($$valPt =~ /^(\x89P|\x8aM|\x8bJ)NG\r\n\x1a\n/) {
        $ext = 'png';
    } elsif ($$valPt =~ /^GIF8[79]a/) {
        $ext = 'gif';
    } elsif ($$valPt =~ /^<\?xpacket/ or $tag eq 'XMP') {
        $ext = 'xmp';
    } elsif ($$valPt =~ /^<\?xml/ or $tag eq 'XML') {
        $ext = 'xml';
    } elsif ($$valPt =~ /^RIFF....WAVE/s) {
        $ext = 'wav';
    } elsif ($tag eq 'OriginalRawFileData' and defined($ext = $et->GetValue('OriginalRawFileName'))) {
        $ext =~ s/^.*\.//s;
        $ext = $ext ? lc($ext) : 'raw';
    } elsif ($tag eq 'EXIF') {
        $ext = 'exif';
    } elsif ($tag eq 'ICC_Profile') {
        $ext = 'icc';
    } elsif ($$valPt =~ /^(MM\0\x2a|II\x2a\0)/) {
        $ext = 'tiff';
    } elsif ($$valPt =~ /^.{4}ftyp(3gp|mp4|f4v|qt  )/s) {
        my %movType = ( 'qt  ' => 'mov' );
        $ext = $movType{$1} || $1;
    } elsif ($$valPt !~ /^.{0,4096}\0/s) {
        $ext = 'txt';
    } elsif ($$valPt =~ /^BM.{15}\0/s) {
        $ext = 'bmp';
    } elsif ($$valPt =~ /^CANON OPTIONAL DATA\0/) {
        $ext = 'vrd';
    } elsif ($$valPt =~ /^IIII\x04\0\x04\0/) {
        $ext = 'dr4';
    } elsif ($$valPt =~ /^(.{10}|.{522})(\x11\x01|\x00\x11)/s) {
        $ext = 'pict';
    } else {
        $ext = 'dat';
    }
    return $ext;
}

#------------------------------------------------------------------------------
# Load print format file
# Inputs: 0) file name
# - saves lines of file to %printFmt list
# - adds tag names to @tags list
sub LoadPrintFormat($)
{
    my $arg = shift;
    if (not defined $arg) {
        Error "Must specify file or expression for -p option\n";
    } elsif ($arg !~ /\n/ and -f $arg and $mt->Open(\*FMT_FILE, $arg)) {
        foreach (<FMT_FILE>) {
            AddPrintFormat($_);
        }
        close(FMT_FILE);
    } else {
        AddPrintFormat($arg . "\n");
    }
}

#------------------------------------------------------------------------------
# A sort of sprintf for filenames
# Inputs: 0) format string (%d=dir, %f=file name, %e=ext),
#         1) source filename or undef to test format string
#         2-4) [%t %g %s only] tag name, ref to array of group names, suggested extension
# Returns: new filename or undef on error (or if no file and fmt contains token)
sub FilenameSPrintf($;$@)
{
    my ($fmt, $file, @extra) = @_;
    local $_;
    # return format string straight away if no tokens
    return $fmt unless $fmt =~ /%[-+]?\d*[.:]?\d*[lu]?[dDfFeEtgs]/;
    return undef unless defined $file;
    CleanFilename($file);   # make sure we are using forward slashes
    # split filename into directory, file, extension
    my %part;
    @part{qw(d f E)} = ($file =~ /^(.*?)([^\/]*?)(\.[^.\/]*)?$/);
    defined $part{f} or Warn("Error: Bad pattern match for file $file\n"), return undef;
    if ($part{E}) {
        $part{e} = substr($part{E}, 1);
    } else {
        @part{qw(e E)} = ('', '');
    }
    $part{F} = $part{f} . $part{E};
    ($part{D} = $part{d}) =~ s{/+$}{};
    @part{qw(t g s)} = @extra;
    my ($filename, $pos) = ('', 0);
    while ($fmt =~ /(%([-+]?)(\d*)([.:]?)(\d*)([lu]?)([dDfFeEtgs]))/g) {
        $filename .= substr($fmt, $pos, pos($fmt) - $pos - length($1));
        $pos = pos($fmt);
        my ($sign, $wid, $dot, $skip, $mod, $code) = ($2, $3, $4, $5 || 0, $6, $7);
        my (@path, $part, $len, $groups);
        if (lc $code eq 'd' and $dot and $dot eq ':') {
            # field width applies to directory levels instead of characters
            @path = split '/', $part{$code};
            $len = scalar @path;
        } else {
            if ($code eq 'g') {
                $groups = $part{g} || [ ] unless defined $groups;
                $fmt =~ /\G(\d?)/g; # look for %g1, %g2, etc
                $part{g} = $$groups[$1 || 0];
                $pos = pos($fmt);
            }
            $part{$code} = '' unless defined $part{$code};
            $len = length $part{$code};
        }
        next unless $skip < $len;
        $wid = $len - $skip if $wid eq '' or $wid + $skip > $len;
        $skip = $len - $wid - $skip if $sign eq '-';
        if (@path) {
            $part = join('/', @path[$skip..($skip+$wid-1)]);
            $part .= '/' unless $code eq 'D';
        } else {
            $part = substr($part{$code}, $skip, $wid);
        }
        $part = ($mod eq 'u') ? uc($part) : lc($part) if $mod;
        $filename .= $part;
    }
    $filename .= substr($fmt, $pos); # add rest of file name
    # remove double slashes (except at beginning to allow Windows UNC paths)
    $filename =~ s{(?!^)//}{/}g;
    return $filename;
}

#------------------------------------------------------------------------------
# Convert number to alphabetical index: a, b, c, ... z, aa, ab ...
# Inputs: 0) number
# Returns: alphabetical index string
sub Num2Alpha($)
{
    my $num = shift;
    my $alpha = chr(97 + ($num % 26));
    while ($num >= 26) {
        $num = int($num / 26) - 1;
        $alpha = chr(97 + ($num % 26)) . $alpha;
    }
    return $alpha;
}

#------------------------------------------------------------------------------
# Expand '%c' and '%C' codes if filename to get next unused file name
# Inputs: 0) file name format string, 1) filename ok to use even if it exists
# Returns: new file name
sub NextUnusedFilename($;$)
{
    my ($fmt, $okfile) = @_;
    return $fmt unless $fmt =~ /%[-+]?\d*\.?\d*[lun]?[cC]/;
    my %sep = ( '-' => '-', '+' => '_' );
    my ($copy, $alpha) = (0, 'a');
    my $seq = $seqFileNum - 1;
    for (;;) {
        my ($filename, $pos) = ('', 0);
        while ($fmt =~ /(%([-+]?)(\d*)(\.?)(\d*)([lun]?)([cC]))/g) {
            $filename .= substr($fmt, $pos, pos($fmt) - $pos - length($1));
            $pos = pos($fmt);
            my ($sign, $wid, $dec, $wid2, $mod, $tok) = ($2, $3 || 0, $4, $5 || 0, $6, $7);
            my $diff;
            if ($tok eq 'C') {
                $diff = $wid - ($sign eq '-' ? $seqFileBase : 0);
                $wid = $wid2;
            } else {
                next unless $dec or $copy;
                $wid = $wid2 if $wid < $wid2;
                # add dash or underline separator if '-' or '+' specified
                $filename .= $sep{$sign} if $sign;
            }
            if ($mod and $mod ne 'n') {
                my $a = $tok eq 'C' ? Num2Alpha($diff + $seq) : $alpha;
                my $str = ($wid and $wid > length $a) ? 'a' x ($wid - length($a)) : '';
                $str .= $a;
                $str = uc $str if $mod eq 'u';
                $filename .= $str;
            } else {
                my $c = $tok eq 'C' ? ($diff + $seq) : $copy;
                my $num = $c + ($mod ? 1 : 0);
                $filename .= $wid ? sprintf("%.${wid}d",$num) : $num;
            }
        }
        $filename .= substr($fmt, $pos); # add rest of file name
        # return now with filename unless file exists
        return $filename unless ($mt->Exists($filename) and not defined $usedFileName{$filename}) or $usedFileName{$filename};
        if (defined $okfile) {
            return $filename if $filename eq $okfile;
            my ($fn, $ok) = (AbsPath($filename), AbsPath($okfile));
            return $okfile if defined $fn and defined $ok and $fn eq $ok;
        }
        ++$copy;
        ++$alpha;
        ++$seq;
    }
}

#------------------------------------------------------------------------------
# Create directory for specified file
# Inputs: 0) complete file name including path
# Returns: true if a directory was created
my $k32CreateDir;
sub CreateDirectory($)
{
    my $file = shift;
    my ($dir, $created);
    ($dir = $file) =~ s/[^\/]*$//;  # remove filename from path specification
    if ($dir and not $mt->IsDirectory($dir)) {
        my @parts = split /\//, $dir;
        $dir = '';
        foreach (@parts) {
            $dir .= $_;
            if (length $dir and not $mt->IsDirectory($dir) and
                # don't try to create a network drive root directory
                not ($hasBackslash{$^O} and $dir =~ m{^//[^/]*$}))
            {
                my $success;
                # create directory since it doesn't exist
                my $d2 = $dir; # (must make a copy in case EncodeFileName recodes it)
                if ($mt->EncodeFileName($d2)) {
                    # handle Windows Unicode directory names
                    unless (eval { require Win32::API }) {
                        Error('Install Win32::API to create directories with Unicode names');
                        return 0;
                    }
                    unless ($k32CreateDir) {
                        $k32CreateDir = new Win32::API('KERNEL32', 'CreateDirectoryW', 'PP', 'I');
                    }
                    $success = $k32CreateDir->Call($d2, 0) if $k32CreateDir;
                } else {
                    $success = mkdir($d2, 0777);
                }
                $success or Error("Error creating directory $dir\n"), return 0;
                $verbose and print $vout "Created directory $dir\n";
                $created = 1;
            }
            $dir .= '/';
        }
        ++$countNewDir if $created;
    }
    return $created;
}

#------------------------------------------------------------------------------
# Open output text file
# Inputs: 0) file name format string, 1-N) extra arguments for FilenameSPrintf
# Returns: 0) file reference (or undef on error), 1) file name if opened, 2) append flag
# Notes: returns reference to STDOUT and no file name if no textOut file needed
sub OpenOutputFile($;@)
{
    my ($file, @args) = @_;
    my ($fp, $outfile, $append);
    if ($textOut) {
        $outfile = $file;
        CleanFilename($outfile);
        if ($textOut =~ /%[-+]?\d*[.:]?\d*[lun]?[dDfFeEtgscC]/ or defined $tagOut) {
            # make filename from printf-like $textOut
            $outfile = FilenameSPrintf($textOut, $file, @args);
            return () unless defined $outfile;
            $outfile = NextUnusedFilename($outfile);
            CreateDirectory($outfile);  # create directory if necessary
        } else {
            $outfile =~ s/\.[^.\/]*$//; # remove extension if it exists
            $outfile .= $textOut;
        }
        my $mode = '>';
        if ($mt->Exists($outfile)) {
            unless ($textOverwrite) {
                Warn "Output file $outfile already exists for $file\n";
                return ();
            }
            if ($textOverwrite == 2 or ($textOverwrite == 3 and $created{$outfile})) {
                $mode = '>>';
                $append = 1;
            }
        }
        unless ($mt->Open(\*OUTFILE, $outfile, $mode)) {
            my $what = $mode eq '>' ? 'creating' : 'appending to';
            Error("Error $what $outfile\n");
            return ();
        }
        binmode(OUTFILE) if $binaryOutput;
        $fp = \*OUTFILE;
    } else {
        $fp = \*STDOUT;
    }
    return($fp, $outfile, $append);
}

#------------------------------------------------------------------------------
# Filter files based on extension
# Inputs: 0) file name
# Returns: 0 = rejected, 1 = specifically accepted, 2 = accepted by default
# Notes: This routine should only be called if $filterFlag is set
sub AcceptFile($)
{
    my $file = shift;
    my $ext = ($file =~ /^.*\.(.+)$/s) ? uc($1) : '';
    return $filterExt{$ext} if defined $filterExt{$ext};
    return $filterExt{'*'} if defined $filterExt{'*'};
    return 0 if $filterFlag & 0x02; # reject if accepting specific extensions
    return 2;   # accept by default
}

#------------------------------------------------------------------------------
# Slurp file into buffer
# Inputs: 0) file name, 1) buffer reference
# Returns: 1 on success
sub SlurpFile($$)
{
    my ($file, $buffPt) = @_;
    $mt->Open(\*INFILE, $file) or Warn("Error opening file $file\n"), return 0;
    binmode(INFILE);
    # (CAREFUL!:  must clear buffer first to reset possible utf8 flag because the data
    #  would be corrupted if it was read into a buffer which had the utf8 flag set!)
    undef $$buffPt;
    my $bsize = 1024 * 1024;
    my $num = read(INFILE, $$buffPt, $bsize);
    unless (defined $num) {
        close(INFILE);
        Warn("Error reading $file\n");
        return 0;
    }
    my $bmax = 64 * $bsize;
    while ($num == $bsize) {
        $bsize *= 2 if $bsize < $bmax;
        my $buff;
        $num = read(INFILE, $buff, $bsize);
        last unless $num;
        $$buffPt .= $buff;
    }
    close(INFILE);
    return 1;
}


#------------------------------------------------------------------------------
# Filter argfile line
# Inputs: 0) line of argfile
# Returns: filtered line or undef to ignore
sub FilterArgfileLine($)
{
    my $arg = shift;
    if ($arg =~ /^#/) {             # comment lines begin with '#'
        return undef unless $arg =~ s/^#\[CSTR\]//;
        $arg =~ s/[\x0d\x0a]+$//s;  # remove trailing newline
        # escape double quotes, dollar signs and ampersands if they aren't already
        # escaped by an odd number of backslashes, and escape a single backslash
        # if it occurs at the end of the string
        $arg =~ s{\\(.)|(["\$\@]|\\$)}{'\\'.($2 || $1)}sge;
        # un-escape characters in C string
        my %esc = ( a => "\a", b => "\b", f => "\f", n => "\n",
                    r => "\r", t => "\t", '"' => '"', '\\' => '\\' );
        $arg =~ s/\\(.)/$esc{$1}||'\\'.$1/egs;
    } else {
        $arg =~ s/^\s+//;           # remove leading white space
        $arg =~ s/[\x0d\x0a]+$//s;  # remove trailing newline
        # remove white space before, and single space after '=', '+=', '-=' or '<='
        $arg =~ s/^(-[-:\w]+#?)\s*([-+<]?=) ?/$1$2/;
        return undef if $arg eq '';
    }
    return $arg;
}

#------------------------------------------------------------------------------
# Read arguments from -stay_open argfile
# Inputs: 0) argument list ref
# Notes: blocks until -execute, -stay_open or -@ option is available
#        (or until there was an error reading from the file)
sub ReadStayOpen($)
{
    my $args = shift;
    my (@newArgs, $processArgs, $result, $optArgs);
    my $lastOpt = '';
    my $unparsed = length $stayOpenBuff;
    for (;;) {
        if ($unparsed) {
            # parse data already read from argfile
            $result = $unparsed;
            undef $unparsed;
        } else {
            # read more data from argfile
            # - this read may block (which is good) if reading from a pipe
            $result = sysread(STAYOPEN, $stayOpenBuff, 65536, length($stayOpenBuff));
        }
        if ($result) {
            my $pos = 0;
            while ($stayOpenBuff =~ /\n/g) {
                my $len = pos($stayOpenBuff) - $pos;
                my $arg = substr($stayOpenBuff, $pos, $len);
                $pos += $len;
                $arg = FilterArgfileLine($arg);
                next unless defined $arg;
                push @newArgs, $arg;
                if ($optArgs) {
                    # this is an argument for the last option
                    undef $optArgs;
                    next unless $lastOpt eq '-stay_open' or $lastOpt eq '-@';
                } else {
                    $optArgs = $optArgs{$arg};
                    $lastOpt = lc $arg;
                    $optArgs = $optArgs{$lastOpt} unless defined $optArgs;
                    next unless $lastOpt =~ /^-execute\d*$/;
                }
                $processArgs = 1;
                last;   # process arguments up to this point
            }
            next unless $pos;   # nothing to do if we didn't read any arguments
            # keep unprocessed data in buffer
            $stayOpenBuff = substr($stayOpenBuff, $pos);
            if ($processArgs) {
                # process new arguments after -execute or -stay_open option
                unshift @$args, @newArgs;
                last;
            }
        } elsif ($result == 0) {
            # sysread() didn't block (eg. when reading from a file),
            # so wait for a short time (1/100 sec) then try again
            # Note: may break out of this early if SIGCONT is received
            select(undef,undef,undef,0.01);
        } else {
            Warn "Error reading from ARGFILE\n";
            close STAYOPEN;
            $stayOpen = 0;
            last;
        }
    }
}

#------------------------------------------------------------------------------
# Add new entry to -efile output file
# Inputs: 0) file name, 1) -efile option number (0=error, 1=same, 2=failed)
sub EFile($$)
{
    my $entry = shift;
    my $efile = $efile[shift || 0];
    if (defined $efile and length $entry and $entry ne '-') {
        my $err;
        CreateDirectory($efile);
        if ($mt->Open(\*EFILE_FILE, $efile, '>>')) {
            print EFILE_FILE $entry, "\n" or Warn("Error writing to $efile\n"), $err = 1;
            close EFILE_FILE;
        } else {
            Warn("Error opening '${efile}' for append\n");
            $err = 1;
        }
        if ($err) {
            defined $_ and $_ eq $efile and undef $_ foreach @efile;
        }
    }
}

#------------------------------------------------------------------------------
# Print list of tags
# Inputs: 0) message, 1-N) list of tag names
sub PrintTagList($@)
{
    my $msg = shift;
    print $msg, ":\n" unless $quiet;
    my $tag;
    if ($outFormat < 0 and $msg =~ /file extensions$/ and @_) {
        foreach $tag (@_) {
            printf("  %-11s %s\n", $tag, GetFileType($tag, 1));
        }
        return;
    }
    my ($len, $pad) = (0, $quiet ? '' : '  ');
    foreach $tag (@_) {
        my $taglen = length($tag);
        if ($len + $taglen > 77) {
            print "\n";
            ($len, $pad) = (0, $quiet ? '' : '  ');
        }
        print $pad, $tag;
        $len += $taglen + 1;
        $pad = ' ';
    }
    @_ or print $pad, '[empty list]';
    print "\n";
}

#------------------------------------------------------------------------------
# Print warnings and errors from info hash
# Inputs: 0) ExifTool object ref, 1) info hash, 2) file name
# Returns: true if there was an Error
sub PrintErrors($$$)
{
    my ($et, $info, $file) = @_;
    my ($tag, $key);
    foreach $tag (qw(Warning Error)) {
        next unless $$info{$tag};
        my @keys = ( $tag );
        push @keys, sort(grep /^$tag /, keys %$info) if $et->Options('Duplicates');
        foreach $key (@keys) {
            Warn "$tag: $info->{$key} - $file\n";
        }
    }
    return $$info{Error};
}

#------------------------------------------------------------------------------
# Print help documentation
sub Help()
{
    my $help = <<'__HELP__';
NAME
    exiftool - Read and write meta information in files

RUNNING IN WINDOWS
    Drag and drop files or folders onto the exiftool executable to display
    meta information, or rename to "exiftool.exe" and run from the command
    line to access all exiftool features.

    This stand-alone Windows version allows simple command-line options to
    be added to the name of the executable (in brackets and separated by
    spaces at the end of the name), providing a mechanism to use options
    when launched via the mouse. For example, changing the executable name
    to "exiftool(-a -u -g1 -w txt).exe" gives a drag-and-drop utility which
    generates sidecar ".txt" files with detailed meta information. As
    shipped, the -k option is added to cause exiftool to pause before
    terminating (keeping the command window open). Options may also be added
    to the "Target" property of a Windows shortcut to the executable.

SYNOPSIS
  Reading
    exiftool [*OPTIONS*] [-*TAG*...] [--*TAG*...] *FILE*...

  Writing
    exiftool [*OPTIONS*] -*TAG*[+-<]=[*VALUE*]... *FILE*...

  Copying
    exiftool [*OPTIONS*] -tagsFromFile *SRCFILE* [-*SRCTAG*[>*DSTTAG*]...]
    *FILE*...

  Other
    exiftool [ -ver | -list[w|f|r|wf|g[*NUM*]|d|x] ]

    For specific examples, see the EXAMPLES sections below.

    This documentation is displayed if exiftool is run without an input
    *FILE* when one is expected.

DESCRIPTION
    A command-line interface to Image::ExifTool, used for reading and
    writing meta information in a variety of file types. *FILE* is one or
    more source file names, directory names, or "-" for the standard input.
    Metadata is read from source files and printed in readable form to the
    console (or written to output text files with -w).

    To write or delete metadata, tag values are assigned using
    -*TAG*=[*VALUE*], and/or the -geotag, -csv= or -json= options. To copy
    or move metadata, the -tagsFromFile feature is used. By default the
    original files are preserved with "_original" appended to their names --
    be sure to verify that the new files are OK before erasing the
    originals. Once in write mode, exiftool will ignore any read-specific
    options.

    Note: If *FILE* is a directory name then only supported file types in
    the directory are processed (in write mode only writable types are
    processed). However, files may be specified by name, or the -ext option
    may be used to force processing of files with any extension. Hidden
    files in the directory are also processed. Adding the -r option causes
    subdirectories to be processed recursively, but subdirectories with
    names beginning with "." are skipped unless -r. is used.

    Below is a list of file types and meta information formats currently
    supported by ExifTool (r = read, w = write, c = create):

      File Types
      ------------+-------------+-------------+-------------+------------
      360   r/w   | DR4   r/w/c | JNG   r/w   | ODP   r     | RIFF  r
      3FR   r     | DSS   r     | JP2   r/w   | ODS   r     | RSRC  r
      3G2   r/w   | DV    r     | JPEG  r/w   | ODT   r     | RTF   r
      3GP   r/w   | DVB   r/w   | JSON  r     | OFR   r     | RW2   r/w
      A     r     | DVR-MS r    | JXL   r     | OGG   r     | RWL   r/w
      AA    r     | DYLIB r     | K25   r     | OGV   r     | RWZ   r
      AAE   r     | EIP   r     | KDC   r     | ONP   r     | RM    r
      AAX   r/w   | EPS   r/w   | KEY   r     | OPUS  r     | SEQ   r
      ACR   r     | EPUB  r     | LA    r     | ORF   r/w   | SKETCH r
      AFM   r     | ERF   r/w   | LFP   r     | ORI   r/w   | SO    r
      AI    r/w   | EXE   r     | LIF   r     | OTF   r     | SR2   r/w
      AIFF  r     | EXIF  r/w/c | LNK   r     | PAC   r     | SRF   r
      APE   r     | EXR   r     | LRV   r/w   | PAGES r     | SRW   r/w
      ARQ   r/w   | EXV   r/w/c | M2TS  r     | PBM   r/w   | SVG   r
      ARW   r/w   | F4A/V r/w   | M4A/V r/w   | PCD   r     | SWF   r
      ASF   r     | FFF   r/w   | MACOS r     | PCX   r     | THM   r/w
      AVI   r     | FITS  r     | MAX   r     | PDB   r     | TIFF  r/w
      AVIF  r/w   | FLA   r     | MEF   r/w   | PDF   r/w   | TORRENT r
      AZW   r     | FLAC  r     | MIE   r/w/  | PEF   r/w   | TTC   r
      BMP   r     | FLIF  r/w   | MIFF  r   c | PFA   r     | TTF   r
      BPG   r     | FLV   r     | MKA   r     | PFB   r     | TXT   r
      BTF   r     | FPF   r     | MKS   r     | PFM   r     | VCF   r
      CHM   r     | FPX   r     | MKV   r     | PGF   r     | VRD   r/w/c
      COS   r     | GIF   r/w   | MNG   r/w   | PGM   r/w   | VSD   r
      CR2   r/w   | GPR   r/w   | MOBI  r     | PLIST r     | WAV   r
      CR3   r/w   | GZ    r     | MODD  r     | PICT  r     | WDP   r/w
      CRM   r/w   | HDP   r/w   | MOI   r     | PMP   r     | WEBP  r
      CRW   r/w   | HDR   r     | MOS   r/w   | PNG   r/w   | WEBM  r
      CS1   r/w   | HEIC  r/w   | MOV   r/w   | PPM   r/w   | WMA   r
      CSV   r     | HEIF  r/w   | MP3   r     | PPT   r     | WMV   r
      CZI   r     | HTML  r     | MP4   r/w   | PPTX  r     | WTV   r
      DCM   r     | ICC   r/w/c | MPC   r     | PS    r/w   | WV    r
      DCP   r/w   | ICS   r     | MPG   r     | PSB   r/w   | X3F   r/w
      DCR   r     | IDML  r     | MPO   r/w   | PSD   r/w   | XCF   r
      DFONT r     | IIQ   r/w   | MQV   r/w   | PSP   r     | XLS   r
      DIVX  r     | IND   r/w   | MRC   r     | QTIF  r/w   | XLSX  r
      DJVU  r     | INSP  r/w   | MRW   r/w   | R3D   r     | XMP   r/w/c
      DLL   r     | INSV  r     | MXF   r     | RA    r     | ZIP   r
      DNG   r/w   | INX   r     | NEF   r/w   | RAF   r/w   |
      DOC   r     | ISO   r     | NRW   r/w   | RAM   r     |
      DOCX  r     | ITC   r     | NUMBERS r   | RAR   r     |
      DPX   r     | J2C   r     | O     r     | RAW   r/w   |

      Meta Information
      ----------------------+----------------------+---------------------
      EXIF           r/w/c  |  CIFF           r/w  |  Ricoh RMETA    r
      GPS            r/w/c  |  AFCP           r/w  |  Picture Info   r
      IPTC           r/w/c  |  Kodak Meta     r/w  |  Adobe APP14    r
      XMP            r/w/c  |  FotoStation    r/w  |  MPF            r
      MakerNotes     r/w/c  |  PhotoMechanic  r/w  |  Stim           r
      Photoshop IRB  r/w/c  |  JPEG 2000      r    |  DPX            r
      ICC Profile    r/w/c  |  DICOM          r    |  APE            r
      MIE            r/w/c  |  Flash          r    |  Vorbis         r
      JFIF           r/w/c  |  FlashPix       r    |  SPIFF          r
      Ducky APP12    r/w/c  |  QuickTime      r    |  DjVu           r
      PDF            r/w/c  |  Matroska       r    |  M2TS           r
      PNG            r/w/c  |  MXF            r    |  PE/COFF        r
      Canon VRD      r/w/c  |  PrintIM        r    |  AVCHD          r
      Nikon Capture  r/w/c  |  FLAC           r    |  ZIP            r
      GeoTIFF        r/w/c  |  ID3            r    |  (and more)

OPTIONS
    Case is not significant for any command-line option (including tag and
    group names), except for single-character options when the corresponding
    upper-case option exists. Many single-character options have equivalent
    long-name versions (shown in brackets), and some options have inverses
    which are invoked with a leading double-dash. Unrecognized options are
    interpreted as tag names (for this reason, multiple single-character
    options may NOT be combined into one argument). Contrary to standard
    practice, options may appear after source file names on the exiftool
    command line.

  Option Overview
    Tag operations

      -TAG or --TAG                    Extract or exclude specified tag
      -TAG[+-^]=[VALUE]                Write new value for tag
      -TAG[+-]<=DATFILE                Write tag value from contents of file
      -TAG[+-]<SRCTAG                  Copy tag value (see -tagsFromFile)

      -tagsFromFile SRCFILE            Copy tag values from file
      -x TAG      (-exclude)           Exclude specified tag

    Input-output text formatting

      -args       (-argFormat)         Format metadata as exiftool arguments
      -b          (-binary)            Output metadata in binary format
      -c FMT      (-coordFormat)       Set format for GPS coordinates
      -charset [[TYPE=]CHARSET]        Specify encoding for special characters
      -csv[[+]=CSVFILE]                Export/import tags in CSV format
      -csvDelim STR                    Set delimiter for CSV file
      -d FMT      (-dateFormat)        Set format for date/time values
      -D          (-decimal)           Show tag ID numbers in decimal
      -E,-ex,-ec  (-escape(HTML|XML|C))Escape tag values for HTML, XML or C
      -f          (-forcePrint)        Force printing of all specified tags
      -g[NUM...]  (-groupHeadings)     Organize output by tag group
      -G[NUM...]  (-groupNames)        Print group name for each tag
      -h          (-htmlFormat)        Use HTML formatting for output
      -H          (-hex)               Show tag ID numbers in hexadecimal
      -htmlDump[OFFSET]                Generate HTML-format binary dump
      -j[[+]=JSONFILE] (-json)         Export/import tags in JSON format
      -l          (-long)              Use long 2-line output format
      -L          (-latin)             Use Windows Latin1 encoding
      -lang [LANG]                     Set current language
      -listItem INDEX                  Extract specific item from a list
      -n          (--printConv)        No print conversion
      -p FMTFILE  (-printFormat)       Print output in specified format
      -php                             Export tags as a PHP Array
      -s[NUM]     (-short)             Short output format
      -S          (-veryShort)         Very short output format
      -sep STR    (-separator)         Set separator string for list items
      -sort                            Sort output alphabetically
      -struct                          Enable output of structured information
      -t          (-tab)               Output in tab-delimited list format
      -T          (-table)             Output in tabular format
      -v[NUM]     (-verbose)           Print verbose messages
      -w[+|!] EXT (-textOut)           Write (or overwrite!) output text files
      -W[+|!] FMT (-tagOut)            Write output text file for each tag
      -Wext EXT   (-tagOutExt)         Write only specified file types with -W
      -X          (-xmlFormat)         Use RDF/XML output format

    Processing control

      -a          (-duplicates)        Allow duplicate tags to be extracted
      -e          (--composite)        Do not generate composite tags
      -ee[NUM]    (-extractEmbedded)   Extract information from embedded files
      -ext[+] EXT (-extension)         Process files with specified extension
      -F[OFFSET]  (-fixBase)           Fix the base for maker notes offsets
      -fast[NUM]                       Increase speed when extracting metadata
      -fileOrder[NUM] [-]TAG           Set file processing order
      -i DIR      (-ignore)            Ignore specified directory name
      -if[NUM] EXPR                    Conditionally process files
      -m          (-ignoreMinorErrors) Ignore minor errors and warnings
      -o OUTFILE  (-out)               Set output file or directory name
      -overwrite_original              Overwrite original by renaming tmp file
      -overwrite_original_in_place     Overwrite original by copying tmp file
      -P          (-preserve)          Preserve file modification date/time
      -password PASSWD                 Password for processing protected files
      -progress[:[TITLE]]              Show file progress count
      -q          (-quiet)             Quiet processing
      -r[.]       (-recurse)           Recursively process subdirectories
      -scanForXMP                      Brute force XMP scan
      -u          (-unknown)           Extract unknown tags
      -U          (-unknown2)          Extract unknown binary tags too
      -wm MODE    (-writeMode)         Set mode for writing/creating tags
      -z          (-zip)               Read/write compressed information

    Other options

      -@ ARGFILE                       Read command-line arguments from file
      -k          (-pause)             Pause before terminating
      -list[w|f|wf|g[NUM]|d|x]         List various exiftool capabilities
      -ver                             Print exiftool version number
      --                               End of options

    Special features

      -geotag TRKFILE                  Geotag images from specified GPS log
      -globalTimeShift SHIFT           Shift all formatted date/time values
      -use MODULE                      Add features from plug-in module

    Utilities

      -delete_original[!]              Delete "_original" backups
      -restore_original                Restore from "_original" backups

    Advanced options

      -api OPT[[^]=[VAL]]              Set ExifTool API option
      -common_args                     Define common arguments
      -config CFGFILE                  Specify configuration file name
      -echo[NUM] TEXT                  Echo text to stdout or stderr
      -efile[NUM][!] ERRFILE           Save names of files with errors
      -execute[NUM]                    Execute multiple commands on one line
      -list_dir                        List directories, not their contents
      -srcfile FMT                     Process a different source file
      -stay_open FLAG                  Keep reading -@ argfile even after EOF
      -userParam PARAM[[^]=[VAL]]      Set user parameter (API UserParam opt)

  Option Details
   Tag operations
    -*TAG*
         Extract information for the specified tag (eg. "-CreateDate").
         Multiple tags may be specified in a single command. A tag name is
         the handle by which a piece of information is referenced. See
         Image::ExifTool::TagNames for documentation on available tag names.
         A tag name may include leading group names separated by colons (eg.
         "-EXIF:CreateDate", or "-Doc1:XMP:Creator"), and each group name
         may be prefixed by a digit to specify family number (eg.
         "-1IPTC:City"). Use the -listg option to list available group names
         by family.

         A special tag name of "All" may be used to indicate all meta
         information (ie. -All). This is particularly useful when a group
         name is specified to extract all information in a group (but beware
         that unless the -a option is also used, some tags in the group may
         be suppressed by same-named tags in other groups). The wildcard
         characters "?" and "*" may be used in a tag name to match any
         single character and zero or more characters respectively. These
         may not be used in a group name, with the exception that a group
         name of "*" (or "All") may be used to extract all instances of a
         tag (as if -a was used). Note that arguments containing wildcards
         must be quoted on the command line of most systems to prevent shell
         globbing.

         A "#" may be appended to the tag name to disable the print
         conversion on a per-tag basis (see the -n option). This may also be
         used when writing or copying tags.

         If no tags are specified, all available information is extracted
         (as if "-All" had been specified).

         Note: Descriptions, not tag names, are shown by default when
         extracting information. Use the -s option to see the tag names
         instead.

    --*TAG*
         Exclude specified tag from extracted information. Same as the -x
         option. Group names and wildcards are permitted as described above
         for -TAG. Once excluded from the output, a tag may not be
         re-included by a subsequent option. May also be used following a
         -tagsFromFile option to exclude tags from being copied (when
         redirecting to another tag, it is the source tag that should be
         excluded), or to exclude groups from being deleted when deleting
         all information (eg. "-all= --exif:all" deletes all but EXIF
         information). But note that this will not exclude individual tags
         from a group delete (unless a family 2 group is specified, see note
         4 below). Instead, individual tags may be recovered using the
         -tagsFromFile option (eg. "-all= -tagsfromfile @ -artist").

    -*TAG*[+-^]=[*VALUE*]
         Write a new value for the specified tag (eg. "-comment=wow"), or
         delete the tag if no *VALUE* is given (eg. "-comment="). "+=" and
         "-=" are used to add or remove existing entries from a list, or to
         shift date/time values (see Image::ExifTool::Shift.pl and note 6
         below for more details). "+=" may also be used to increment
         numerical values (or decrement if *VALUE* is negative), and "-="
         may be used to conditionally delete or replace a tag (see "WRITING
         EXAMPLES" for examples). "^=" is used to write an empty string
         instead of deleting the tag when no *VALUE* is given, but otherwise
         it is equivalent to "=".

         *TAG* may contain one or more leading family 0, 1, 2 or 7 group
         names, prefixed by optional family numbers, and separated colons.
         If no group name is specified, the tag is created in the preferred
         group, and updated in any other location where a same-named tag
         already exists. The preferred group in JPEG and TIFF-format images
         is the first group in the following list where *TAG* is valid: 1)
         EXIF, 2) IPTC, 3) XMP.

         The wildcards "*" and "?" may be used in tag names to assign the
         same value to multiple tags. When specified with wildcards,
         "Unsafe" tags are not written. A tag name of "All" is equivalent to
         "*" (except that it doesn't require quoting, while arguments with
         wildcards do on systems with shell globbing), and is often used
         when deleting all metadata (ie. "-All=") or an entire group (eg.
         "-XMP-dc:All=", see note 4 below). Note that not all groups are
         deletable, and that the JPEG APP14 "Adobe" group is not removed by
         default with "-All=" because it may affect the appearance of the
         image. However, color space information is removed, so the colors
         may be affected (but this may be avoided by copying back the tags
         defined by the ColorSpaceTags shortcut). Use the -listd option for
         a complete list of deletable groups, and see note 5 below regarding
         the "APP" groups. Also, within an image some groups may be
         contained within others, and these groups are removed if the
         containing group is deleted:

           JPEG Image:
           - Deleting EXIF or IFD0 also deletes ExifIFD, GlobParamIFD,
             GPS, IFD1, InteropIFD, MakerNotes, PrintIM and SubIFD.
           - Deleting ExifIFD also deletes InteropIFD and MakerNotes.
           - Deleting Photoshop also deletes IPTC.

           TIFF Image:
           - Deleting EXIF only removes ExifIFD which also deletes
             InteropIFD and MakerNotes.

         Notes:

         1) Many tag values may be assigned in a single command. If two
         assignments affect the same tag, the latter takes precedence
         (except for list-type tags, for which both values are written).

         2) In general, MakerNotes tags are considered "Permanent", and may
         be edited but not created or deleted individually. This avoids many
         potential problems, including the inevitable compatibility problems
         with OEM software which may be very inflexible about the
         information it expects to find in the maker notes.

         3) Changes to PDF files by ExifTool are reversible (by deleting the
         update with "-PDF-update:all=") because the original information is
         never actually deleted from the file. So ExifTool alone may not be
         used to securely edit metadata in PDF files.

         4) Specifying "-GROUP:all=" deletes the entire group as a block
         only if a single family 0 or 1 group is specified. Otherwise all
         deletable tags in the specified group(s) are removed individually,
         and in this case is it possible to exclude individual tags from a
         mass delete. For example, "-time:all --Exif:Time:All" removes all
         deletable Time tags except those in the EXIF. This difference also
         applies if family 2 is specified when deleting all groups. For
         example, "-2all:all=" deletes tags individually, while "-all:all="
         deletes entire blocks.

         5) The "APP" group names ("APP0" through "APP15") are used to
         delete JPEG application segments which are not associated with
         another deletable group. For example, specifying "-APP14:All=" will
         NOT delete the APP14 "Adobe" segment because this is accomplished
         with "-Adobe:All".

         6) When shifting a value, the shift is applied to the original
         value of the tag, overriding any other values previously assigned
         to the tag on the same command line. To shift a date/time value and
         copy it to another tag in the same operation, use the
         -globalTimeShift option.

         Special feature: Integer values may be specified in hexadecimal
         with a leading "0x", and simple rational values may be specified as
         fractions.

    -*TAG*<=*DATFILE* or -*TAG*<=*FMT*
         Set the value of a tag from the contents of file *DATFILE*. The
         file name may also be given by a *FMT* string where %d, %f and %e
         represent the directory, file name and extension of the original
         *FILE* (see the -w option for more details). Note that quotes are
         required around this argument to prevent shell redirection since it
         contains a "<" symbol. If *DATFILE*/*FMT* is not provided, the
         effect is the same as "-TAG=", and the tag is simply deleted. "+<="
         or "-<=" may also be used to add or delete specific list entries,
         or to shift date/time values.

    -tagsFromFile *SRCFILE* or *FMT*
         Copy tag values from *SRCFILE* to *FILE*. Tag names on the command
         line after this option specify the tags to be copied, or excluded
         from the copy. Wildcards are permitted in these tag names. If no
         tags are specified, then all possible tags (see note 1 below) from
         the source file are copied to same-named tags in the preferred
         location of the output file (the same as specifying "-all"). More
         than one -tagsFromFile option may be used to copy tags from
         multiple files.

         By default, this option will update any existing and writable
         same-named tags in the output *FILE*, but will create new tags only
         in their preferred groups. This allows some information to be
         automatically transferred to the appropriate group when copying
         between images of different formats. However, if a group name is
         specified for a tag then the information is written only to this
         group (unless redirected to another group, see below). If "All" is
         used as a group name, then the specified tag(s) are written to the
         same family 1 group they had in the source file (ie. the same
         specific location, like ExifIFD or XMP-dc). For example, the common
         operation of copying all writable tags to the same specific
         locations in the output *FILE* is achieved by adding "-all:all". A
         different family may be specified by adding a leading family number
         to the group name (eg. "-0all:all" preserves the same general
         location, like EXIF or XMP).

         *SRCFILE* may be the same as *FILE* to move information around
         within a single file. In this case, "@" may be used to represent
         the source file (ie. "-tagsFromFile @"), permitting this feature to
         be used for batch processing multiple files. Specified tags are
         then copied from each file in turn as it is rewritten. For advanced
         batch use, the source file name may also be specified using a *FMT*
         string in which %d, %f and %e represent the directory, file name
         and extension of *FILE*. (eg. the current *FILE* would be
         represented by "%d%f.%e", with the same effect as "@"). See the -w
         option for *FMT* string examples.

         A powerful redirection feature allows a destination tag to be
         specified for each copied tag. With this feature, information may
         be written to a tag with a different name or group. This is done
         using "-*DSTTAG*<*SRCTAG*" or "-*SRCTAG*>*DSTTAG*" on the command
         line after -tagsFromFile, and causes the value of *SRCTAG* to be
         copied from *SRCFILE* and written to *DSTTAG* in *FILE*. Has no
         effect unless *SRCTAG* exists in *SRCFILE*. Note that this argument
         must be quoted to prevent shell redirection, and there is no "="
         sign as when assigning new values. Source and/or destination tags
         may be prefixed by a group name and/or suffixed by "#". Wildcards
         are allowed in both the source and destination tag names. A
         destination group and/or tag name of "All" or "*" writes to the
         same family 1 group and/or tag name as the source. If no
         destination group is specified, the information is written to the
         preferred group. Whitespace around the ">" or "<" is ignored. As a
         convenience, "-tagsFromFile @" is assumed for any redirected tags
         which are specified without a prior -tagsFromFile option. Copied
         tags may also be added or deleted from a list with arguments of the
         form "-*SRCTAG*+<*DSTTAG*" or "-*SRCTAG*-<*DSTTAG*" (but see Note 5
         below).

         An extension of the redirection feature allows strings involving
         tag names to be used on the right hand side of the "<" symbol with
         the syntax "-*DSTTAG*<*STR*", where tag names in *STR* are prefixed
         with a "$" symbol. See the -p option and the "Advanced formatting
         feature" section for more details about this syntax. Strings
         starting with a "=" sign must insert a single space after the "<"
         to avoid confusion with the "<=" operator which sets the tag value
         from the contents of a file. A single space at the start of the
         string is removed if it exists, but all other whitespace in the
         string is preserved. See note 8 below about using the redirection
         feature with list-type stags, shortcuts or when using wildcards in
         tag names.

         See "COPYING EXAMPLES" for examples using -tagsFromFile.

         Notes:

         1) Some tags (generally tags which may affect the appearance of the
         image) are considered "Unsafe" to write, and are only copied if
         specified explicitly (ie. no wildcards). See the tag name
         documentation for more details about "Unsafe" tags.

         2) Be aware of the difference between excluding a tag from being
         copied (--*TAG*), and deleting a tag (-*TAG*=). Excluding a tag
         prevents it from being copied to the destination image, but
         deleting will remove a pre-existing tag from the image.

         3) The maker note information is copied as a block, so it isn't
         affected like other information by subsequent tag assignments on
         the command line, and individual makernote tags may not be excluded
         from a block copy. Also, since the PreviewImage referenced from the
         maker notes may be rather large, it is not copied, and must be
         transferred separately if desired.

         4) The order of operations is to copy all specified tags at the
         point of the -tagsFromFile option in the command line. Any tag
         assignment to the right of the -tagsFromFile option is made after
         all tags are copied. For example, new tag values are set in the
         order One, Two, Three then Four with this command:

             exiftool -One=1 -tagsFromFile s.jpg -Two -Four=4 -Three d.jpg

         This is significant in the case where an overlap exists between the
         copied and assigned tags because later operations may override
         earlier ones.

         5) The normal behaviour of copied tags differs from that of
         assigned tags for list-type tags and conditional replacements
         because each copy operation on a tag overrides any previous
         operations. While this avoids duplicate list items when copying
         groups of tags from a file containing redundant information, it
         also prevents values of different tags from being copied into the
         same list when this is the intent. So a -addTagsFromFile option is
         provided which allows copying of multiple tags into the same list.
         eg)

             exiftool -addtagsfromfile @ "-subject<make" "-subject<model" ...

         Similarly, -addTagsFromFile must be used when conditionally
         replacing a tag to prevent overriding earlier conditions.

         Other than these differences, the -tagsFromFile and
         -addTagsFromFile options are equivalent.

         6) The -a option (allow duplicate tags) is always in effect when
         copying tags from *SRCFILE*, but the highest priority tag is always
         copied last so it takes precedence.

         7) Structured tags are copied by default when copying tags. See the
         -struct option for details.

         8) With the redirection feature, copying a tag directly (ie.
         "'-*DSTTAG*<*SRCTAG*'") is not the same as interpolating its value
         inside a string (ie. "'-*DSTTAG*<$*SRCTAG*'") for list-type tags,
         shortcut tags, tag names containing wildcards, or UserParam
         variables. When copying directly, the values of each matching
         source tag are copied individually to the destination tag (as if
         they were separate assignments). However, when interpolated inside
         a string, list items and the values of shortcut tags are
         concatenated (with a separator set by the -sep option), and
         wildcards are not allowed. Also, UserParam variables are available
         only when interpolated in a string. Another difference is that a
         minor warning is generated if a tag doesn't exist when
         interpolating its value in a string (with "$"), but isn't when
         copying the tag directly.

         Finally, the behaviour is different when a destination tag or group
         of "All" is used. When copying directly, a destination group and/or
         tag name of "All" writes to the same family 1 group and/or tag name
         as the source. But when interpolated in a string, the identity of
         the source tags are lost and the value is written to all possible
         groups/tags. For example, the string form must be used in the
         following command since the intent is to set the value of all
         existing date/time tags from "CreateDate":

             exiftool "-time:all<$createdate" -wm w FILE

    -x *TAG* (-exclude)
         Exclude the specified tag. There may be multiple -x options. This
         has the same effect as --*TAG* on the command line. See the --*TAG*
         documentation above for a complete description.

   Input-output text formatting
    Note that trailing spaces are removed from extracted values for most
    output text formats. The exceptions are -b, -csv, -j and -X.

    -args (-argFormat)
         Output information in the form of exiftool arguments, suitable for
         use with the -@ option when writing. May be combined with the -G
         option to include group names. This feature may be used to
         effectively copy tags between images, but allows the metadata to be
         altered by editing the intermediate file ("out.args" in this
         example):

             exiftool -args -G1 --filename --directory src.jpg > out.args
             exiftool -@ out.args -sep ", " dst.jpg

         Note: Be careful when copying information with this technique since
         it is easy to write tags which are normally considered "Unsafe".
         For instance, the FileName and Directory tags are excluded in the
         example above to avoid renaming and moving the destination file.
         Also note that the second command above will produce warning
         messages for any tags which are not writable.

         As well, the -sep option should be used as in the second command
         above to maintain separate list items when writing metadata back to
         image files, and the -struct option may be used when extracting to
         preserve structured XMP information.

    -b, --b (-binary, --binary)
         Output requested metadata in binary format without tag names or
         descriptions (-b or -binary). This option is mainly used for
         extracting embedded images or other binary data, but it may also be
         useful for some text strings since control characters (such as
         newlines) are not replaced by '.' as they are in the default
         output. By default, list items are separated by a newline when
         extracted with the -b option, but this may be changed (see the -sep
         option for details). May be combined with -j, -php or -X to extract
         binary data in JSON, PHP or XML format, but note that "Unsafe" tags
         are not extracted as binary unless they are specified explicitly or
         the API RequestAll option is set to 3 or higher.

         With a leading double dash (--b or --binary), tags which contain
         binary data are suppressed in the output when reading.

    -c *FMT* (-coordFormat)
         Set the print format for GPS coordinates. *FMT* uses the same
         syntax as a "printf" format string. The specifiers correspond to
         degrees, minutes and seconds in that order, but minutes and seconds
         are optional. For example, the following table gives the output for
         the same coordinate using various formats:

                     FMT                  Output
             -------------------    ------------------
             "%d deg %d' %.2f"\"    54 deg 59' 22.80"  (default for reading)
             "%d %d %.8f"           54 59 22.80000000  (default for copying)
             "%d deg %.4f min"      54 deg 59.3800 min
             "%.6f degrees"         54.989667 degrees

         Notes:

         1) To avoid loss of precision, the default coordinate format is
         different when copying tags using the -tagsFromFile option.

         2) If the hemisphere is known, a reference direction (N, S, E or W)
         is appended to each printed coordinate, but adding a "+" to the
         format specifier (eg. "%+.6f") prints a signed coordinate instead.

         3) This print formatting may be disabled with the -n option to
         extract coordinates as signed decimal degrees.

    -charset [[*TYPE*=]*CHARSET*]
         If *TYPE* is "ExifTool" or not specified, this option sets the
         ExifTool character encoding for output tag values when reading and
         input values when writing, with a default of "UTF8". If no
         *CHARSET* is given, a list of available character sets is returned.
         Valid *CHARSET* values are:

             CHARSET     Alias(es)        Description
             ----------  ---------------  ----------------------------------
             UTF8        cp65001, UTF-8   UTF-8 characters (default)
             Latin       cp1252, Latin1   Windows Latin1 (West European)
             Latin2      cp1250           Windows Latin2 (Central European)
             Cyrillic    cp1251, Russian  Windows Cyrillic
             Greek       cp1253           Windows Greek
             Turkish     cp1254           Windows Turkish
             Hebrew      cp1255           Windows Hebrew
             Arabic      cp1256           Windows Arabic
             Baltic      cp1257           Windows Baltic
             Vietnam     cp1258           Windows Vietnamese
             Thai        cp874            Windows Thai
             DOSLatinUS  cp437            DOS Latin US
             DOSLatin1   cp850            DOS Latin1
             DOSCyrillic cp866            DOS Cyrillic
             MacRoman    cp10000, Roman   Macintosh Roman
             MacLatin2   cp10029          Macintosh Latin2 (Central Europe)
             MacCyrillic cp10007          Macintosh Cyrillic
             MacGreek    cp10006          Macintosh Greek
             MacTurkish  cp10081          Macintosh Turkish
             MacRomanian cp10010          Macintosh Romanian
             MacIceland  cp10079          Macintosh Icelandic
             MacCroatian cp10082          Macintosh Croatian

         *TYPE* may be "FileName" to specify the encoding of file names on
         the command line (ie. *FILE* arguments). In Windows, this triggers
         use of wide-character i/o routines, thus providing support for
         Unicode file names. See the "WINDOWS UNICODE FILE NAMES" section
         below for details.

         Other values of *TYPE* listed below are used to specify the
         internal encoding of various meta information formats.

             TYPE       Description                                  Default
             ---------  -------------------------------------------  -------
             EXIF       Internal encoding of EXIF "ASCII" strings    (none)
             ID3        Internal encoding of ID3v1 information       Latin
             IPTC       Internal IPTC encoding to assume when        Latin
                         IPTC:CodedCharacterSet is not defined
             Photoshop  Internal encoding of Photoshop IRB strings   Latin
             QuickTime  Internal encoding of QuickTime strings       MacRoman
             RIFF       Internal encoding of RIFF strings            0

         See <https://exiftool.org/faq.html#Q10> for more information about
         coded character sets, and the Image::ExifTool Options for more
         details about the -charset settings.

    -csv[[+]=*CSVFILE*]
         Export information in CSV format, or import information if
         *CSVFILE* is specified. When importing, the CSV file must be in
         exactly the same format as the exported file. The first row of the
         *CSVFILE* must be the ExifTool tag names (with optional group
         names) for each column of the file, and values must be separated by
         commas. A special "SourceFile" column specifies the files
         associated with each row of information (and a SourceFile of "*"
         may be used to define default tags to be imported for all files
         which are combined with any tags specified for the specific
         SourceFile processed). The -csvDelim option may be used to change
         the input/output field delimiter if something other than a comma is
         required.

         The following examples demonstrate basic use of the -csv option:

             # generate CSV file with common tags from all images in a directory
             exiftool -common -csv dir > out.csv

             # update metadata for all images in a directory from CSV file
             exiftool -csv=a.csv dir

         Empty values are ignored when importing (unless the -f option is
         used and the API MissingTagValue is set to an empty string, in
         which case the tag is deleted). Also, FileName and Directory
         columns are ignored if they exist (ie. ExifTool will not attempt to
         write these tags with a CSV import). To force a tag to be deleted,
         use the -f option and set the value to "-" in the CSV file (or to
         the MissingTagValue if this API option was used). Multiple
         databases may be imported in a single command.

         When exporting a CSV file, the -g or -G option adds group names to
         the tag headings. If the -a option is used to allow duplicate tag
         names, the duplicate tags are only included in the CSV output if
         the column headings are unique. Adding the -G4 option ensures a
         unique column heading for each tag. The -b option may be added to
         output binary data, encoded in base64 if necessary (indicated by
         ASCII "base64:" as the first 7 bytes of the value). Values may also
         be encoded in base64 if the -charset option is used and the value
         contains invalid characters.

         When exporting specific tags, the CSV columns are arranged in the
         same order as the specified tags provided the column headings
         exactly match the specified tag names, otherwise the columns are
         sorted in alphabetical order.

         When importing from a CSV file, only files specified on the command
         line are processed. Any extra entries in the CSV file are ignored.

         List-type tags are stored as simple strings in a CSV file, but the
         -sep option may be used to split them back into separate items when
         importing.

         Special feature: -csv+=*CSVFILE* may be used to add items to
         existing lists. This affects only list-type tags. Also applies to
         the -j option.

         Note that this option is fundamentally different than all other
         output format options because it requires information from all
         input files to be buffered in memory before the output is written.
         This may result in excessive memory usage when processing a very
         large number of files with a single command. Also, it makes this
         option incompatible with the -w option. When processing a large
         number of files, it is recommended to either use the JSON (-j) or
         XML (-X) output format, or use -p to generate a fixed-column CSV
         file instead of using the -csv option.

    -csvDelim *STR*
         Set the delimiter for separating CSV entries for CSV file
         input/output via the -csv option. *STR* may contain "\t", "\n",
         "\r" and "\\" to represent TAB, LF, CR and '\' respectively. A
         double quote is not allowed in the delimiter. Default is ','.

    -d *FMT* (-dateFormat)
         Set the format for date/time tag values. The *FMT* string may
         contain formatting codes beginning with a percent character ("%")
         to represent the various components of a date/time value. The
         specifics of the *FMT* syntax are system dependent -- consult the
         "strftime" man page on your system for details. The default format
         is equivalent to "%Y:%m:%d %H:%M:%S". This option has no effect on
         date-only or time-only tags and ignores timezone information if
         present. Only one -d option may be used per command. Requires
         POSIX::strptime or Time::Piece for the inversion conversion when
         writing.

    -D (-decimal)
         Show tag ID number in decimal when extracting information.

    -E, -ex, -ec (-escapeHTML, -escapeXML, -escapeC)
         Escape characters in output tag values for HTML (-E), XML (-ex) or
         C (-ec). For HTML, all characters with Unicode code points above
         U+007F are escaped as well as the following 5 characters: & (&amp;)
         ' (&#39;) " (&quot;) > (&gt;) and < (&lt;). For XML, only these 5
         characters are escaped. The -E option is implied with -h, and -ex
         is implied with -X. For C, all control characters and the backslash
         are escaped. The inverse conversion is applied when writing tags.

    -f (-forcePrint)
         Force printing of tags even if their values are not found. This
         option only applies when specific tags are requested on the command
         line (ie. not with wildcards or by "-all"). With this option, a
         dash ("-") is printed for the value of any missing tag, but the
         dash may be changed via the API MissingTagValue option. May also be
         used to add a 'flags' attribute to the -listx output, or to allow
         tags to be deleted when writing with the -csv=*CSVFILE* feature.

    -g[*NUM*][:*NUM*...] (-groupHeadings)
         Organize output by tag group. *NUM* specifies a group family
         number, and may be 0 (general location), 1 (specific location), 2
         (category), 3 (document number), 4 (instance number), 5 (metadata
         path), 6 (EXIF/TIFF format) or 7 (tag ID). -g0 is assumed if a
         family number is not specified. May be combined with other options
         to add group names to the output. Multiple families may be
         specified by separating them with colons. By default the resulting
         group name is simplified by removing any leading "Main:" and
         collapsing adjacent identical group names, but this can be avoided
         by placing a colon before the first family number (eg. -g:3:1). Use
         the -listg option to list group names for a specified family. The
         API SavePath and SaveFormat options are automatically enabled if
         the respective family 5 or 6 group names are requested. See the API
         GetGroup documentation for more information.

    -G[*NUM*][:*NUM*...] (-groupNames)
         Same as -g but print group name for each tag. -G0 is assumed if
         *NUM* is not specified. May be combined with a number of other
         options to add group names to the output. Note that *NUM* may be
         added wherever -G is mentioned in the documentation. See the -g
         option above for details.

    -h (-htmlFormat)
         Use HTML table formatting for output. Implies the -E option. The
         formatting options -D, -H, -g, -G, -l and -s may be used in
         combination with -h to influence the HTML format.

    -H (-hex)
         Show tag ID number in hexadecimal when extracting information.

    -htmlDump[*OFFSET*]
         Generate a dynamic web page containing a hex dump of the EXIF
         information. This can be a very powerful tool for low-level
         analysis of EXIF information. The -htmlDump option is also invoked
         if the -v and -h options are used together. The verbose level
         controls the maximum length of the blocks dumped. An *OFFSET* may
         be given to specify the base for displayed offsets. If not
         provided, the EXIF/TIFF base offset is used. Use -htmlDump0 for
         absolute offsets. Currently only EXIF/TIFF and JPEG information is
         dumped, but the -u option can be used to give a raw hex dump of
         other file formats.

    -j[[+]=*JSONFILE*] (-json)
         Use JSON (JavaScript Object Notation) formatting for console
         output, or import JSON file if *JSONFILE* is specified. This option
         may be combined with -g to organize the output into objects by
         group, or -G to add group names to each tag. List-type tags with
         multiple items are output as JSON arrays unless -sep is used. By
         default XMP structures are flattened into individual tags in the
         JSON output, but the original structure may be preserved with the
         -struct option (this also causes all list-type XMP tags to be
         output as JSON arrays, otherwise single-item lists would be output
         as simple strings). The -a option is implied when -json is used,
         but entries with identical JSON names are suppressed in the output.
         (-G4 may be used to ensure that all tags have unique JSON names.)
         Adding the -D or -H option changes tag values to JSON objects with
         "val" and "id" fields, and adding -l adds a "desc" field, and a
         "num" field if the numerical value is different from the converted
         "val". The -b option may be added to output binary data, encoded in
         base64 if necessary (indicated by ASCII "base64:" as the first 7
         bytes of the value), and -t may be added to include tag table
         information (see -t for details). The JSON output is UTF-8
         regardless of any -L or -charset option setting, but the UTF-8
         validation is disabled if a character set other than UTF-8 is
         specified.

         If *JSONFILE* is specified, the file is imported and the tag
         definitions from the file are used to set tag values on a per-file
         basis. The special "SourceFile" entry in each JSON object
         associates the information with a specific target file. An object
         with a missing SourceFile or a SourceFile of "*" defines default
         tags for all target files which are combined with any tags
         specified for the specific SourceFile processed. The imported JSON
         file must have the same format as the exported JSON files with the
         exception that the -g option is not compatible with the import file
         format (use -G instead). Additionally, tag names in the input JSON
         file may be suffixed with a "#" to disable print conversion.

         Unlike CSV import, empty values are not ignored, and will cause an
         empty value to be written if supported by the specific metadata
         type. Tags are deleted by using the -f option and setting the tag
         value to "-" (or to the MissingTagValue setting if this API option
         was used). Importing with -j+=*JSONFILE* causes new values to be
         added to existing lists.

    -l (-long)
         Use long 2-line Canon-style output format. Adds a description and
         unconverted value (if it is different from the converted value) to
         the XML, JSON or PHP output when -X, -j or -php is used. May also
         be combined with -listf, -listr or -listwf to add descriptions of
         the file types.

    -L (-latin)
         Use Windows Latin1 encoding (cp1252) for output tag values instead
         of the default UTF-8. When writing, -L specifies that input text
         values are Latin1 instead of UTF-8. Equivalent to "-charset latin".

    -lang [*LANG*]
         Set current language for tag descriptions and converted values.
         *LANG* is "de", "fr", "ja", etc. Use -lang with no other arguments
         to get a list of available languages. The default language is "en"
         if -lang is not specified. Note that tag/group names are always
         English, independent of the -lang setting, and translation of
         warning/error messages has not yet been implemented. May also be
         combined with -listx to output descriptions in one language only.

         By default, ExifTool uses UTF-8 encoding for special characters,
         but the the -L or -charset option may be used to invoke other
         encodings. Note that ExifTool uses Unicode::LineBreak if available
         to help preserve the column alignment of the plain text output for
         languages with a variable-width character set.

         Currently, the language support is not complete, but users are
         welcome to help improve this by submitting their own translations.
         To submit a translation, follow these steps (you must have Perl
         installed for this):

         1. Download and unpack the latest Image-ExifTool full distribution.

         2. "cd" into the Image-ExifTool directory.

         3. Run this command to make an XML file of the desired tags (eg.
         EXIF):

            ./exiftool -listx -exif:all > out.xml

         4. Copy this text into a file called "import.pl" in the exiftool
         directory:

             push @INC, 'lib';
             require Image::ExifTool::TagInfoXML;
             my $file = shift or die "Expected XML file name\n";
             $Image::ExifTool::TagInfoXML::makeMissing = shift;
             Image::ExifTool::TagInfoXML::BuildLangModules($file,8);

         5. Run the "import.pl" script to Import the XML file, generating
         the "MISSING" entries for your language (eg. Russian):

            perl import.pl out.xml ru

         6. Edit the generated language module
         lib/Image/ExifTool/Lang/ru.pm, and search and replace all "MISSING"
         strings in the file with your translations.

         7. Email the module ('ru.pm' in this example) to philharvey66 at
         gmail.com

         8. Thank you!!

    -listItem *INDEX*
         For list-type tags, this causes only the item with the specified
         index to be extracted. *INDEX* is 0 for the first item in the list.
         Negative indices may also be used to reference items from the end
         of the list. Has no effect on single-valued tags. Also applies to
         tag values when copying from a tag, and in -if conditions.

    -n (--printConv)
         Disable print conversion for all tags. By default, extracted values
         are converted to a more human-readable format, but the -n option
         disables this conversion, revealing the machine-readable values.
         For example:

             > exiftool -Orientation -S a.jpg
             Orientation: Rotate 90 CW
             > exiftool -Orientation -S -n a.jpg
             Orientation: 6

         The print conversion may also be disabled on a per-tag basis by
         suffixing the tag name with a "#" character:

             > exiftool -Orientation# -Orientation -S a.jpg
             Orientation: 6
             Orientation: Rotate 90 CW

         These techniques may also be used to disable the inverse print
         conversion when writing. For example, the following commands all
         have the same effect:

             > exiftool -Orientation="Rotate 90 CW" a.jpg
             > exiftool -Orientation=6 -n a.jpg
             > exiftool -Orientation#=6 a.jpg

    -p *FMTFILE* or *STR* (-printFormat)
         Print output in the format specified by the given file or string.
         The argument is interpreted as a string unless a file of that name
         exists, in which case the string is loaded from the contents of the
         file. Tag names in the format file or string begin with a "$"
         symbol and may contain leading group names and/or a trailing "#"
         (to disable print conversion). Case is not significant. Braces "{}"
         may be used around the tag name to separate it from subsequent
         text. Use $$ to represent a "$" symbol, and $/ for a newline.

         Multiple -p options may be used, each contributing a line (or more)
         of text to the output. Lines beginning with "#[HEAD]" and "#[TAIL]"
         are output before the first processed file and after the last
         processed file respectively. Lines beginning with "#[SECT]" and
         "#[ENDS]" are output before and after each section of files. A
         section is defined as a group of consecutive files with the same
         section header (eg. files are grouped by directory if "#[SECT]"
         contains $directory). Lines beginning with "#[BODY]" and lines not
         beginning with "#" are output for each processed file. Lines
         beginning with "#[IF]" are not output, but all BODY lines are
         skipped if any tag on an IF line doesn't exist. Other lines
         beginning with "#" are ignored. For example, this format file:

             # this is a comment line
             #[HEAD]-- Generated by ExifTool $exifToolVersion --
             File: $FileName - $DateTimeOriginal
             (f/$Aperture, ${ShutterSpeed}s, ISO $EXIF:ISO)
             #[TAIL]-- end --

         with this command:

             exiftool -p test.fmt a.jpg b.jpg

         produces output like this:

             -- Generated by ExifTool 12.33 --
             File: a.jpg - 2003:10:31 15:44:19
             (f/5.6, 1/60s, ISO 100)
             File: b.jpg - 2006:05:23 11:57:38
             (f/8.0, 1/13s, ISO 100)
             -- end --

         The values of List-type tags with multiple items and Shortcut tags
         representing multiple tags are joined according the the -sep option
         setting when interpolated in the string.

         When -ee (-extractEmbedded) is combined with -p, embedded documents
         are effectively processed as separate input files.

         If a specified tag does not exist, a minor warning is issued and
         the line with the missing tag is not printed. However, the -f
         option may be used to set the value of missing tags to '-' (but
         this may be configured via the API MissingTagValue option), or the
         -m option may be used to ignore minor warnings and leave the
         missing values empty. Alternatively, -q -q may be used to simply
         suppress the warning messages.

         The "Advanced formatting feature" may be used to modify the values
         of individual tags with the -p option.

    -php Format output as a PHP Array. The -g, -G, -D, -H, -l, -sep and
         -struct options combine with -php, and duplicate tags are handled
         in the same way as with the -json option. As well, the -b option
         may be added to output binary data, and -t may be added to include
         tag table information (see -t for details). Here is a simple
         example showing how this could be used in a PHP script:

             <?php
             eval('$array=' . `exiftool -php -q image.jpg`);
             print_r($array);
             ?>

    -s[*NUM*] (-short)
         Short output format. Prints tag names instead of descriptions. Add
         *NUM* or up to 3 -s options for even shorter formats:

             -s1 or -s        - print tag names instead of descriptions
             -s2 or -s -s     - no extra spaces to column-align values
             -s3 or -s -s -s  - print values only (no tag names)

         Also effective when combined with -t, -h, -X or -listx options.

    -S (-veryShort)
         Very short format. The same as -s2 or two -s options. Tag names are
         printed instead of descriptions, and no extra spaces are added to
         column-align values.

    -sep *STR* (-separator)
         Specify separator string for items in list-type tags. When reading,
         the default is to join list items with ", ". When writing, this
         option causes values assigned to list-type tags to be split into
         individual items at each substring matching *STR* (otherwise they
         are not split by default). Space characters in *STR* match zero or
         more whitespace characters in the value.

         Note that an empty separator ("") is allowed, and will join items
         with no separator when reading, or split the value into individual
         characters when writing.

         For pure binary output (-b used without -j, -php or -X), the first
         -sep option specifies a list-item separator, and a second -sep
         option specifies a terminator for the end of the list (or after
         each value if not a list). In these strings, "\n", "\r" and "\t"
         may be used to represent a newline, carriage return and tab
         respectively. By default, binary list items are separated by a
         newline, and no terminator is added.

    -sort, --sort
         Sort output by tag description, or by tag name if the -s option is
         used. When sorting by description, the sort order will depend on
         the -lang option setting. Without the -sort option, tags appear in
         the order they were specified on the command line, or if not
         specified, the order they were extracted from the file. By default,
         tags are organized by groups when combined with the -g or -G
         option, but this grouping may be disabled with --sort.

    -struct, --struct
         Output structured XMP information instead of flattening to
         individual tags. This option works well when combined with the XML
         (-X) and JSON (-j) output formats. For other output formats, XMP
         structures and lists are serialized into the same format as when
         writing structured information (see
         <https://exiftool.org/struct.html> for details). When copying,
         structured tags are copied by default unless --struct is used to
         disable this feature (although flattened tags may still be copied
         by specifying them individually unless -struct is used). These
         options have no effect when assigning new values since both
         flattened and structured tags may always be used when writing.

    -t (-tab)
         Output a tab-delimited list of description/values (useful for
         database import). May be combined with -s to print tag names
         instead of descriptions, or -S to print tag values only,
         tab-delimited on a single line. The -t option may be combined with
         -j, -php or -X to add tag table information ("table", tag "id", and
         "index" for cases where multiple conditional tags exist with the
         same ID).

    -T (-table)
         Output tag values in table form. Equivalent to -t -S -q -f.

    -v[*NUM*] (-verbose)
         Print verbose messages. *NUM* specifies the level of verbosity in
         the range 0-5, with higher numbers being more verbose. If *NUM* is
         not given, then each -v option increases the level of verbosity by
         1. With any level greater than 0, most other options are ignored
         and normal console output is suppressed unless specific tags are
         extracted. Using -v0 causes the console output buffer to be flushed
         after each line (which may be useful to avoid delays when piping
         exiftool output), and prints the name of each processed file when
         writing. Also see the -progress option.

    -w[+|!] *EXT* or *FMT* (-textOut)
         Write console output to files with names ending in *EXT*, one for
         each source file. The output file name is obtained by replacing the
         source file extension (including the '.') with the specified
         extension (and a '.' is added to the start of *EXT* if it doesn't
         already contain one). Alternatively, a *FMT* string may be used to
         give more control over the output file name and directory. In the
         format string, %d, %f and %e represent the directory, filename and
         extension of the source file, and %c represents a copy number which
         is automatically incremented if the file already exists. %d
         includes the trailing '/' if necessary, but %e does not include the
         leading '.'. For example:

             -w %d%f.txt       # same effect as "-w txt"
             -w dir/%f_%e.out  # write files to "dir" as "FILE_EXT.out"
             -w dir2/%d%f.txt  # write to "dir2", keeping dir structure
             -w a%c.txt        # write to "a.txt" or "a1.txt" or "a2.txt"...

         Existing files will not be changed unless an exclamation point is
         added to the option name (ie. -w! or -textOut!) to overwrite the
         file, or a plus sign (ie. -w+ or -textOut+) to append to the
         existing file. Both may be used (ie. -w+! or -textOut+!) to
         overwrite output files that didn't exist before the command was
         run, and append the output from multiple source files. For example,
         to write one output file for all source files in each directory:

             exiftool -filename -createdate -T -w+! %d/out.txt -r DIR

         Capitalized format codes %D, %F, %E and %C provide slightly
         different alternatives to the lower case versions. %D does not
         include the trailing '/', %F is the full filename including
         extension, %E includes the leading '.', and %C increments the count
         for each processed file (see below).

         Notes:

         1) In a Windows BAT file the "%" character is represented by "%%",
         so an argument like "%d%f.txt" is written as "%%d%%f.txt".

         2) If the argument for -w does not contain a valid format code (eg.
         %f), then it is interpreted as a file extension, but there are
         three different ways to create a single output file from multiple
         source files:

             # 1. Shell redirection
             exiftool FILE1 FILE2 ... > out.txt

             # 2. With the -w option and a zero-width format code
             exiftool -w+! %0fout.txt FILE1 FILE2 ...

             # 3. With the -W option (see the -W option below)
             exiftool -W+! out.txt FILE1 FILE2 ...

         Advanced features:

         A substring of the original file name, directory or extension may
         be taken by specifying a field width immediately following the '%'
         character. If the width is negative, the substring is taken from
         the end. The substring position (characters to ignore at the start
         or end of the string) may be given by a second optional value after
         a decimal point. For example:

             Input File Name     Format Specifier    Output File Name
             ----------------    ----------------    ----------------
             Picture-123.jpg     %7f.txt             Picture.txt
             Picture-123.jpg     %-.4f.out           Picture.out
             Picture-123.jpg     %7f.%-3f            Picture.123
             Picture-123a.jpg    Meta%-3.1f.txt      Meta123.txt

         (Note that special characters may have a width of greater than
         one.)

         For %d and %D, the field width/position specifiers may be applied
         to the directory levels instead of substring position by using a
         colon instead of a decimal point in the format specifier. For
         example:

             Source Dir     Format   Result       Notes
             ------------   ------   ----------   ------------------
             pics/2012/02   %2:d     pics/2012/   take top 2 levels
             pics/2012/02   %-:1d    pics/2012/   up one directory level
             pics/2012/02   %:1d     2012/02/     ignore top level
             pics/2012/02   %1:1d    2012/        take 1 level after top
             pics/2012/02   %-1:D    02           bottom level folder name
             /Users/phil    %:2d     phil/        ignore top 2 levels

         (Note that the root directory counts as one level when an absolute
         path is used as in the last example above.)

         For %c, these modifiers have a different effects. If a field width
         is given, the copy number is padded with zeros to the specified
         width. A leading '-' adds a dash before the copy number, and a '+'
         adds an underline. By default, the copy number is omitted from the
         first file of a given name, but this can be changed by adding a
         decimal point to the modifier. For example:

             -w A%-cZ.txt      # AZ.txt, A-1Z.txt, A-2Z.txt ...
             -w B%5c.txt       # B.txt, B00001.txt, B00002.txt ...
             -w C%.c.txt       # C0.txt, C1.txt, C2.txt ...
             -w D%-.c.txt      # D-0.txt, D-1.txt, D-2.txt ...
             -w E%-.4c.txt     # E-0000.txt, E-0001.txt, E-0002.txt ...
             -w F%-.4nc.txt    # F-0001.txt, F-0002.txt, F-0003.txt ...
             -w G%+c.txt       # G.txt, G_1.txt G_2.txt ...
             -w H%-lc.txt      # H.txt, H-b.txt, H-c.txt ...
             -w I.%.3uc.txt    # I.AAA.txt, I.AAB.txt, I.AAC.txt ...

         A special feature allows the copy number to be incremented for each
         processed file by using %C (upper case) instead of %c. This allows
         a sequential number to be added to output file names, even if the
         names are different. For %C, a copy number of zero is not omitted
         as it is with %c. A leading '-' causes the number to be reset at
         the start of each new directory, and '+' has no effect. The number
         before the decimal place gives the starting index, the number after
         the decimal place gives the field width. The following examples
         show the output filenames when used with the command "exiftool
         rose.jpg star.jpg jet.jpg ...":

             -w %C%f.txt       # 0rose.txt, 1star.txt, 2jet.txt
             -w %f-%10C.txt    # rose-10.txt, star-11.txt, jet-12.txt
             -w %.3C-%f.txt    # 000-rose.txt, 001-star.txt, 002-jet.txt
             -w %57.4C%f.txt   # 0057rose.txt, 0058star.txt, 0059jet.txt

         All format codes may be modified by 'l' or 'u' to specify lower or
         upper case respectively (ie. %le for a lower case file extension).
         When used to modify %c or %C, the numbers are changed to an
         alphabetical base (see example H above). Also, %c and %C may be
         modified by 'n' to count using natural numbers starting from 1,
         instead of 0 (see example F above).

         This same *FMT* syntax is used with the -o and -tagsFromFile
         options, although %c and %C are only valid for output file names.

    -W[+|!] *FMT* (-tagOut)
         This enhanced version of the -w option allows a separate output
         file to be created for each extracted tag. See the -w option
         documentation above for details of the basic functionality. Listed
         here are the differences between -W and -w:

         1) With -W, a new output file is created for each extracted tag.

         2) -W supports three additional format codes: %t, %g and %s
         represent the tag name, group name, and suggested extension for the
         output file (based on the format of the data). The %g code may be
         followed by a single digit to specify the group family number (eg.
         %g1), otherwise family 0 is assumed. The substring
         width/position/case specifiers may be used with these format codes
         in exactly the same way as with %f and %e.

         3) The argument for -W is interpreted as a file name if it contains
         no format codes. (For -w, this would be a file extension.) This
         change allows a simple file name to be specified, which, when
         combined with the append feature, provides a method to write
         metadata from multiple source files to a single output file without
         the need for shell redirection. For example, the following pairs of
         commands give the same result:

             # overwriting existing text file
             exiftool test.jpg > out.txt     # shell redirection
             exiftool test.jpg -W+! out.txt  # equivalent -W option

             # append to existing text file
             exiftool test.jpg >> out.txt    # shell redirection
             exiftool test.jpg -W+ out.txt   # equivalent -W option

         4) Adding the -v option to -W sends a list of the tags and output
         file names to the console instead of giving a verbose dump of the
         entire file. (Unless appending all output to one file for each
         source file by using -W+ with an output file *FMT* that does not
         contain %t, $g or %s.)

         5) Individual list items are stored in separate files when -W is
         combined with -b, but note that for separate files to be created %c
         or %C must be used in *FMT* to give the files unique names.

    -Wext *EXT*, --Wext *EXT* (-tagOutExt)
         This option is used to specify the type of output file(s) written
         by the -W option. An output file is written only if the suggested
         extension matches *EXT*. Multiple -Wext options may be used to
         write more than one type of file. Use --Wext to write all but the
         specified type(s).

    -X (-xmlFormat)
         Use ExifTool-specific RDF/XML formatting for console output.
         Implies the -a option, so duplicate tags are extracted. The
         formatting options -b, -D, -H, -l, -s, -sep, -struct and -t may be
         used in combination with -X to affect the output, but note that the
         tag ID (-D, -H and -t), binary data (-b) and structured output
         (-struct) options are not effective for the short output (-s).
         Another restriction of -s is that only one tag with a given group
         and name may appear in the output. Note that the tag ID options
         (-D, -H and -t) will produce non-standard RDF/XML unless the -l
         option is also used.

         By default, -X outputs flattened tags, so -struct should be added
         if required to preserve XMP structures. List-type tags with
         multiple values are formatted as an RDF Bag, but they are combined
         into a single string when -s or -sep is used. Using -L changes the
         XML encoding from "UTF-8" to "windows-1252". Other -charset
         settings change the encoding only if there is a corresponding
         standard XML character set. The -b option causes binary data values
         to be written, encoded in base64 if necessary. The -t option adds
         tag table information to the output (see -t for details).

         Note: This output is NOT the same as XMP because it uses
         dynamically-generated property names corresponding to the ExifTool
         tag names with ExifTool family 1 group names as namespaces, and not
         the standard XMP properties and namespaces. To write XMP instead,
         use the -o option with an XMP extension for the output file.

   Processing control
    -a, --a (-duplicates, --duplicates)
         Allow (-a) or suppress (--a) duplicate tag names to be extracted.
         By default, duplicate tags are suppressed when reading unless the
         -ee or -X options are used or the Duplicates option is enabled in
         the configuration file. This option has an affect when writing only
         to allow duplicate Warning messages to be shown. Duplicate tags are
         always extracted when copying.

    -e (--composite)
         Extract existing tags only -- don't generate composite tags.

    -ee[*NUM*] (-extractEmbedded)
         Extract information from embedded documents in EPS files, embedded
         EPS information and JPEG and Jpeg2000 images in PDF files, embedded
         MPF images in JPEG and MPO files, streaming metadata in AVCHD
         videos, and the resource fork of Mac OS files. Implies the -a
         option. Use -g3 or -G3 to identify the originating document for
         extracted information. Embedded documents containing sub-documents
         are indicated with dashes in the family 3 group name. (eg. "Doc2-3"
         is the 3rd sub-document of the 2nd embedded document.) Note that
         this option may increase processing time substantially, especially
         for PDF files with many embedded images or videos with streaming
         metadata.

         When used with -ee, the -p option is evaluated for each embedded
         document as if it were a separate input file. This allows, for
         example, generation of GPS track logs from timed metadata in
         videos. See <https://exiftool.org/geotag.html#Inverse> for
         examples.

         Setting *NUM* to 2 causes the H264 video stream in MP4 videos to be
         parsed until the first Supplemental Enhancement Information (SEI)
         message is decoded, or 3 to parse the entire H624 stream and decode
         all SEI information. For M2TS videos, a setting of 3 causes the
         entire file to be parsed in search of unlisted programs which may
         contain timed GPS.

    -ext[+] *EXT*, --ext *EXT* (-extension)
         Process only files with (-ext) or without (--ext) a specified
         extension. There may be multiple -ext and --ext options. A plus
         sign may be added (ie. -ext+) to add the specified extension to the
         normally processed files. EXT may begin with a leading ".", which
         is ignored. Case is not significant. "*" may be used to process
         files with any extension (or none at all), as in the last three
         examples:

             exiftool -ext JPG DIR             # process only JPG files
             exiftool --ext cr2 --ext dng DIR  # supported files but CR2/DNG
             exiftool -ext+ txt DIR            # supported files plus TXT
             exiftool -ext "*" DIR             # process all files
             exiftool -ext "*" --ext xml DIR   # process all but XML files
             exiftool -ext "*" --ext . DIR     # all but those with no ext

         Using this option has two main advantages over specifying "*.*EXT*"
         on the command line: 1) It applies to files in subdirectories when
         combined with the -r option. 2) The -ext option is
         case-insensitive, which is useful when processing files on
         case-sensitive filesystems.

         Note that all files specified on the command line will be processed
         regardless of extension unless the -ext option is used.

    -F[*OFFSET*] (-fixBase)
         Fix the base for maker notes offsets. A common problem with some
         image editors is that offsets in the maker notes are not adjusted
         properly when the file is modified. This may cause the wrong values
         to be extracted for some maker note entries when reading the edited
         file. This option allows an integer *OFFSET* to be specified for
         adjusting the maker notes base offset. If no *OFFSET* is given,
         ExifTool takes its best guess at the correct base. Note that
         exiftool will automatically fix the offsets for images which store
         original offset information (eg. newer Canon models). Offsets are
         fixed permanently if -F is used when writing EXIF to an image. eg)

             exiftool -F -exif:resolutionunit=inches image.jpg

    -fast[*NUM*]
         Increase speed of extracting information. With -fast (or -fast1),
         ExifTool will not scan to the end of a JPEG image to check for an
         AFCP or PreviewImage trailer, or past the first comment in GIF
         images or the audio/video data in WAV/AVI files to search for
         additional metadata. These speed benefits are small when reading
         images directly from disk, but can be substantial if piping images
         through a network connection. For more substantial speed benefits,
         -fast2 also causes exiftool to avoid extracting any EXIF MakerNote
         information. -fast3 avoids extracting metadata from the file, and
         returns only pseudo System tags, but still reads the file header to
         obtain an educated guess at FileType. -fast4 doesn't even read the
         file header, and returns only System tags and a FileType based on
         the file extension. -fast5 also disables generation of the
         Composite tags (like -e). Has no effect when writing.

         Note that a separate -fast setting may be used for evaluation of a
         -if condition, or when ordering files with the -fileOrder option.
         See the -if and -fileOrder options for details.

    -fileOrder[*NUM*] [-]*TAG*
         Set file processing order according to the sorted value of the
         specified *TAG*. For example, to process files in order of date:

             exiftool -fileOrder DateTimeOriginal DIR

         Additional -fileOrder options may be added for secondary sort keys.
         Numbers are sorted numerically, and all other values are sorted
         alphabetically. Files missing the specified tag are sorted last.
         The sort order may be reversed by prefixing the tag name with a "-"
         (eg. "-fileOrder -createdate"). Print conversion of the sorted
         values is disabled with the -n option, or a "#" appended to the tag
         name. Other formatting options (eg. -d) have no effect on the
         sorted values. Note that the -fileOrder option can have a large
         performance impact since it involves an additional processing pass
         of each file, but this impact may be reduced by specifying a *NUM*
         for the -fast level used during the metadata-extraction phase. For
         example, -fileOrder4 may be used if *TAG* is a pseudo System tag.
         If multiple -fileOrder options are used, the extraction is done at
         the lowest -fast level. Note that files are sorted across directory
         boundaries if multiple input directories are specified.

    -i *DIR* (-ignore)
         Ignore specified directory name. *DIR* may be either an individual
         folder name, or a full path. If a full path is specified, it must
         match the Directory tag exactly to be ignored. Use multiple -i
         options to ignore more than one directory name. A special *DIR*
         value of "SYMLINKS" (case sensitive) may be specified to avoid
         recursing into directories which are symbolic links when the -r
         option is used. As well, a value of "HIDDEN" (case sensitive) may
         be used to ignore files with names that start with a "." (ie.
         hidden files on Unix systems) when scanning a directory.

    -if[*NUM*] *EXPR*
         Specify a condition to be evaluated before processing each *FILE*.
         *EXPR* is a Perl-like logic expression containing tag names
         prefixed by "$" symbols. It is evaluated with the tags from each
         *FILE* in turn, and the file is processed only if the expression
         returns true. Unlike Perl variable names, tag names are not case
         sensitive and may contain a hyphen. As well, tag names may have a
         leading group names separated by colons, and/or a trailing "#"
         character to disable print conversion. The expression $GROUP:all
         evaluates to 1 if any tag exists in the specified "GROUP", or 0
         otherwise (see note 2 below). When multiple -if options are used,
         all conditions must be satisfied to process the file. Returns an
         exit status of 2 if all files fail the condition. Below are a few
         examples:

             # extract shutterspeed from all Canon images in a directory
             exiftool -shutterspeed -if "$make eq 'Canon'" dir

             # add one hour to all images created on or after Apr. 2, 2006
             exiftool -alldates+=1 -if "$CreateDate ge '2006:04:02'" dir

             # set EXIF ISO value if possible, unless it is set already
             exiftool "-exif:iso<iso" -if "not $exif:iso" dir

             # find images containing a specific keyword (case insensitive)
             exiftool -if "$keywords =~ /harvey/i" -filename dir

         Adding *NUM* to the -if option causes a separate processing pass to
         be executed for evaluating *EXPR* at a -fast level given by *NUM*
         (see the -fast option documentation for details). Without *NUM*,
         only one processing pass is done at the level specified by the
         -fast option. For example, using -if5 is possible if *EXPR* uses
         only pseudo System tags, and may significantly speed processing if
         enough files fail the condition.

         The expression has access to the current ExifTool object through
         $self, and the following special functions are available to allow
         short-circuiting of the file processing. Both functions have a
         return value of 1. Case is significant for function names.

             End()    - end processing after this file
             EndDir() - end processing of files in this directory (not
                        compatible with the B<-fileOrder> option)

         Notes:

         1) The -n and -b options also apply to tags used in *EXPR*.

         2) Some binary data blocks are not extracted unless specified
         explicitly. These tags are not available for use in the -if
         condition unless they are also specified on the command line. The
         alternative is to use the $GROUP:all syntax. (eg. Use $exif:all
         instead of $exif in *EXPR* to test for the existence of EXIF tags.)

         3) Tags in the string are interpolated the same way as with -p
         before the expression is evaluated. In this interpolation, $/ is
         converted to a newline and $$ represents a single "$" symbol (so
         Perl variables, if used, require a double "$").

         4) The condition may only test tags from the file being processed.
         To process one file based on tags from another, two steps are
         required. For example, to process XMP sidecar files in directory
         "DIR" based on tags from the associated NEF:

             exiftool -if EXPR -p '$directory/$filename' -ext nef DIR > nef.txt
             exiftool -@ nef.txt -srcfile %d%f.xmp ...

         5) The -a option has no effect on the evaluation of the expression,
         and the values of duplicate tags are accessible only by specifying
         a group name (such as a family 4 instance number, eg. $Copy1:TAG,
         $Copy2:TAG, etc).

         6) A special "OK" UserParam is available to test the success of the
         previous command when -execute was used, and may be used like any
         other tag in the condition (ie. "$OK").

    -m (-ignoreMinorErrors)
         Ignore minor errors and warnings. This enables writing to files
         with minor errors and disables some validation checks which could
         result in minor warnings. Generally, minor errors/warnings indicate
         a problem which usually won't result in loss of metadata if
         ignored. However, there are exceptions, so ExifTool leaves it up to
         you to make the final decision. Minor errors and warnings are
         indicated by "[minor]" at the start of the message. Warnings which
         affect processing when ignored are indicated by "[Minor]" (with a
         capital "M"). Note that this causes missing values in
         -tagsFromFile, -p and -if strings to be set to an empty string
         rather than an undefined value.

    -o *OUTFILE* or *FMT* (-out)
         Set the output file or directory name when writing information.
         Without this option, when any "real" tags are written the original
         file is renamed to "FILE_original" and output is written to *FILE*.
         When writing only FileName and/or Directory "pseudo" tags, -o
         causes the file to be copied instead of moved, but directories
         specified for either of these tags take precedence over that
         specified by the -o option.

         *OUTFILE* may be "-" to write to stdout. The output file name may
         also be specified using a *FMT* string in which %d, %f and %e
         represent the directory, file name and extension of *FILE*. Also,
         %c may be used to add a copy number. See the -w option for *FMT*
         string examples.

         The output file is taken to be a directory name if it already
         exists as a directory or if the name ends with '/'. Output
         directories are created if necessary. Existing files will not be
         overwritten. Combining the -overwrite_original option with -o
         causes the original source file to be erased after the output file
         is successfully written.

         A special feature of this option allows the creation of certain
         types of files from scratch, or with the metadata from another type
         of file. The following file types may be created using this
         technique:

             XMP, EXIF, EXV, MIE, ICC/ICM, VRD, DR4

         The output file type is determined by the extension of *OUTFILE*
         (specified as "-.EXT" when writing to stdout). The output file is
         then created from a combination of information in *FILE* (as if the
         -tagsFromFile option was used), and tag values assigned on the
         command line. If no *FILE* is specified, the output file may be
         created from scratch using only tags assigned on the command line.

    -overwrite_original
         Overwrite the original *FILE* (instead of preserving it by adding
         "_original" to the file name) when writing information to an image.
         Caution: This option should only be used if you already have
         separate backup copies of your image files. The overwrite is
         implemented by renaming a temporary file to replace the original.
         This deletes the original file and replaces it with the edited
         version in a single operation. When combined with -o, this option
         causes the original file to be deleted if the output file was
         successfully written (ie. the file is moved instead of copied).

    -overwrite_original_in_place
         Similar to -overwrite_original except that an extra step is added
         to allow the original file attributes to be preserved. For example,
         on a Mac this causes the original file creation date, type,
         creator, label color, icon, Finder tags, other extended attributes
         and hard links to the file to be preserved (but note that the Mac
         OS resource fork is always preserved unless specifically deleted
         with "-rsrc:all="). This is implemented by opening the original
         file in update mode and replacing its data with a copy of a
         temporary file before deleting the temporary. The extra step
         results in slower performance, so the -overwrite_original option
         should be used instead unless necessary.

         Note that this option reverts to the behaviour of the
         -overwrite_original option when also writing the FileName and/or
         Directory tags.

    -P (-preserve)
         Preserve the filesystem modification date/time ("FileModifyDate")
         of the original file when writing. Note that some filesystems store
         a creation date (ie. "FileCreateDate" on Windows and Mac systems)
         which is not affected by this option. This creation date is
         preserved on Windows systems where Win32API::File and Win32::API
         are available regardless of this setting. For other systems, the
         -overwrite_original_in_place option may be used if necessary to
         preserve the creation date. The -P option is superseded by any
         value written to the FileModifyDate tag.

    -password *PASSWD*
         Specify password to allow processing of password-protected PDF
         documents. If a password is required but not given, a warning is
         issued and the document is not processed. This option is ignored if
         a password is not required.

    -progress[:[*TITLE*]]
         Show the progress when processing files. Without a colon, the
         -progress option adds a progress count in brackets after the name
         of each processed file, giving the current file number and the
         total number of files to be processed. Implies the -v0 option,
         causing the names of processed files to also be printed when
         writing. When combined with the -if option, the total count
         includes all files before the condition is applied, but files that
         fail the condition will not have their names printed.

         If followed by a colon (ie. -progress:), the console window title
         is set according to the specified *TITLE* string. If no *TITLE* is
         given, a default *TITLE* string of "ExifTool %p%%" is assumed. In
         the string, %f represents the file name, %p is the progress as a
         percent, %r is the progress as a ratio, %##b is a progress bar of
         width "##" (20 characters if "##" is omitted), and %% is a %
         character. May be combined with the normal -progress option to also
         show the progress count in console messages. (Note: For this
         feature to function correctly on Mac/Linux, stderr must go to the
         console.)

    -q (-quiet)
         Quiet processing. One -q suppresses normal informational messages,
         and a second -q suppresses warnings as well. Error messages can not
         be suppressed, although minor errors may be downgraded to warnings
         with the -m option, which may then be suppressed with "-q -q".

    -r[.] (-recurse)
         Recursively process files in subdirectories. Only meaningful if
         *FILE* is a directory name. Subdirectories with names beginning
         with "." are not processed unless "." is added to the option name
         (ie. -r. or -recurse.). By default, exiftool will also follow
         symbolic links to directories if supported by the system, but this
         may be disabled with "-i SYMLINKS" (see the -i option for details).
         Combine this with -ext options to control the types of files
         processed.

    -scanForXMP
         Scan all files (even unsupported formats) for XMP information
         unless found already. When combined with the -fast option, only
         unsupported file types are scanned. Warning: It can be time
         consuming to scan large files.

    -u (-unknown)
         Extract values of unknown tags. Add another -u to also extract
         unknown information from binary data blocks. This option applies to
         tags with numerical tag ID's, and causes tag names like
         "Exif_0xc5d9" to be generated for unknown information. It has no
         effect on information types which have human-readable tag ID's
         (such as XMP), since unknown tags are extracted automatically from
         these formats.

    -U (-unknown2)
         Extract values of unknown tags as well as unknown information from
         some binary data blocks. This is the same as two -u options.

    -wm *MODE* (-writeMode)
         Set mode for writing/creating tags. *MODE* is a string of one or
         more characters from the list below. The default write mode is
         "wcg".

             w - Write existing tags
             c - Create new tags
             g - create new Groups as necessary

         For example, use "-wm cg" to only create new tags (and avoid
         editing existing ones).

         The level of the group is the SubDirectory level in the metadata
         structure. For XMP or IPTC this is the full XMP/IPTC block (the
         family 0 group), but for EXIF this is the individual IFD (the
         family 1 group).

    -z (-zip)
         When reading, causes information to be extracted from .gz and .bz2
         compressed images (only one image per archive; requires gzip and
         bzip2 to be available). When writing, causes compressed information
         to be written if supported by the metadata format (eg. compressed
         textual metadata in PNG), disables the recommended padding in
         embedded XMP (saving 2424 bytes when writing XMP in a file), and
         writes XMP in shorthand format -- the equivalent of setting the API
         Compress=1 and Compact="NoPadding,Shorthand".

   Other options
    -@ *ARGFILE*
         Read command-line arguments from the specified file. The file
         contains one argument per line (NOT one option per line -- some
         options require additional arguments, and all arguments must be
         placed on separate lines). Blank lines and lines beginning with "#"
         are ignored (unless they start with "#[CSTR]", in which case the
         rest of the line is treated as a C string, allowing standard C
         escape sequences such as "\n" for a newline). White space at the
         start of a line is removed. Normal shell processing of arguments is
         not performed, which among other things means that arguments should
         not be quoted and spaces are treated as any other character.
         *ARGFILE* may exist relative to either the current directory or the
         exiftool directory unless an absolute pathname is given.

         For example, the following *ARGFILE* will set the value of
         Copyright to "Copyright YYYY, Phil Harvey", where "YYYY" is the
         year of CreateDate:

             -d
             %Y
             -copyright<Copyright $createdate, Phil Harvey

         Arguments in *ARGFILE* behave exactly the same as if they were
         entered at the location of the -@ option on the command line, with
         the exception that the -config and -common_args options may not be
         used in an *ARGFILE*.

    -k (-pause)
         Pause with the message "-- press any key --" before terminating.
         This option is used to prevent the command window from closing when
         run as a Windows drag and drop application.

    -list, -listw, -listf, -listr, -listwf, -listg[*NUM*], -listd, -listx
         Print a list of all valid tag names (-list), all writable tag names
         (-listw), all supported file extensions (-listf), all recognized
         file extensions (-listr), all writable file extensions (-listwf),
         all tag groups [in a specified family] (-listg[*NUM*]), all
         deletable tag groups (-listd), or an XML database of tag details
         including language translations (-listx). The -list, -listw and
         -listx options may be followed by an additional argument of the
         form "-GROUP:All" to list only tags in a specific group, where
         "GROUP" is one or more family 0-2 group names (excepting EXIF IFD
         groups) separated by colons. With -listg, *NUM* may be given to
         specify the group family, otherwise family 0 is assumed. The -l
         option may be combined with -listf, -listr or -listwf to add file
         descriptions to the list. The -lang option may be combined with
         -listx to output descriptions in a single language. Here are some
         examples:

             -list               # list all tag names
             -list -EXIF:All     # list all EXIF tags
             -list -xmp:time:all # list all XMP tags relating to time
             -listw -XMP-dc:All  # list all writable XMP-dc tags
             -listf              # list all supported file extensions
             -listr              # list all recognized file extensions
             -listwf             # list all writable file extensions
             -listg1             # list all groups in family 1
             -listd              # list all deletable groups
             -listx -EXIF:All    # list database of EXIF tags in XML format
             -listx -XMP:All -s  # list short XML database of XMP tags

         When combined with -listx, the -s option shortens the output by
         omitting the descriptions and values (as in the last example
         above), and -f adds a 'flags' attribute if applicable. The flags
         are formatted as a comma-separated list of the following possible
         values: Avoid, Binary, List, Mandatory, Permanent, Protected,
         Unknown and Unsafe (see the Tag Name documentation). For XMP List
         tags, the list type (Alt, Bag or Seq) is added to the flags, and
         flattened structure tags are indicated by a Flattened flag.

         Note that none of the -list options require an input *FILE*.

    -ver Print exiftool version number. The -v option may be added to print
         addition system information (see the README file of the full
         distribution for more details about optional libraries), or -v2 to
         also list the Perl include directories.

    --   Indicates the end of options. Any remaining arguments are treated
         as file names, even if they begin with a dash ("-").

   Special features
    -geotag *TRKFILE*
         Geotag images from the specified GPS track log file. Using the
         -geotag option is equivalent to writing a value to the "Geotag"
         tag. The GPS position is interpolated from the track at a time
         specified by the value written to the "Geotime" tag. If "Geotime"
         is not specified, the value is copied from "DateTimeOriginal#" (the
         "#" is added to copy the unformatted value, avoiding potential
         conflicts with the -d option). For example, the following two
         commands are equivalent:

             exiftool -geotag trk.log image.jpg
             exiftool -geotag trk.log "-Geotime<DateTimeOriginal#" image.jpg

         When the "Geotime" value is converted to UTC, the local system
         timezone is assumed unless the date/time value contains a timezone.
         Writing "Geotime" causes the following tags to be written (provided
         they can be calculated from the track log, and they are supported
         by the destination metadata format): GPSLatitude, GPSLatitudeRef,
         GPSLongitude, GPSLongitudeRef, GPSAltitude, GPSAltitudeRef,
         GPSDateStamp, GPSTimeStamp, GPSDateTime, GPSTrack, GPSTrackRef,
         GPSSpeed, GPSSpeedRef, GPSImgDirection, GPSImgDirectionRef,
         GPSPitch, GPSRoll, AmbientTemperature and CameraElevationAngle. By
         default, tags are created in EXIF, and updated in XMP only if they
         already exist. However, "EXIF:Geotime" or "XMP:Geotime" may be
         specified to write only EXIF or XMP tags respectively. Note that
         GPSPitch and GPSRoll are non-standard, and require user-defined
         tags in order to be written.

         The "Geosync" tag may be used to specify a time correction which is
         applied to each "Geotime" value for synchronization with GPS time.
         For example, the following command compensates for image times
         which are 1 minute and 20 seconds behind GPS:

             exiftool -geosync=+1:20 -geotag a.log DIR

         Advanced "Geosync" features allow a linear time drift correction
         and synchronization from previously geotagged images. See
         "geotag.html" in the full ExifTool distribution for more
         information.

         Multiple -geotag options may be used to concatenate GPS track log
         data. Also, a single -geotag option may be used to load multiple
         track log files by using wildcards in the *TRKFILE* name, but note
         that in this case *TRKFILE* must be quoted on most systems (with
         the notable exception of Windows) to prevent filename expansion.
         For example:

             exiftool -geotag "TRACKDIR/*.log" IMAGEDIR

         Currently supported track file formats are GPX, NMEA RMC/GGA/GLL,
         KML, IGC, Garmin XML and TCX, Magellan PMGNTRK, Honeywell PTNTHPR,
         Bramor gEO, Winplus Beacon TXT, and GPS/IMU CSV files. See
         "GEOTAGGING EXAMPLES" for examples. Also see "geotag.html" in the
         full ExifTool distribution and the Image::ExifTool Options for more
         details and for information about geotag configuration options.

    -globalTimeShift *SHIFT*
         Shift all formatted date/time values by the specified amount when
         reading. Does not apply to unformatted (-n) output. *SHIFT* takes
         the same form as the date/time shift when writing (see
         Image::ExifTool::Shift.pl for details), with a negative shift being
         indicated with a minus sign ("-") at the start of the *SHIFT*
         string. For example:

             # return all date/times, shifted back by 1 hour
             exiftool -globalTimeShift -1 -time:all a.jpg

             # set the file name from the shifted CreateDate (-1 day) for
             # all images in a directory
             exiftool "-filename<createdate" -globaltimeshift "-0:0:1 0:0:0" \
                 -d %Y%m%d-%H%M%S.%%e dir

    -use *MODULE*
         Add features from specified plug-in *MODULE*. Currently, the MWG
         module is the only plug-in module distributed with exiftool. This
         module adds read/write support for tags as recommended by the
         Metadata Working Group. As a convenience, "-use MWG" is assumed if
         the "MWG" group is specified for any tag on the command line. See
         the MWG Tags documentation for more details. Note that this option
         is not reversible, and remains in effect until the application
         terminates, even across the -execute option.

   Utilities
    -restore_original
    -delete_original[!]
         These utility options automate the maintenance of the "_original"
         files created by exiftool. They have no effect on files without an
         "_original" copy. The -restore_original option restores the
         specified files from their original copies by renaming the
         "_original" files to replace the edited versions. For example, the
         following command restores the originals of all JPG images in
         directory "DIR":

             exiftool -restore_original -ext jpg DIR

         The -delete_original option deletes the "_original" copies of all
         files specified on the command line. Without a trailing "!" this
         option prompts for confirmation before continuing. For example, the
         following command deletes "a.jpg_original" if it exists, after
         asking "Are you sure?":

             exiftool -delete_original a.jpg

         These options may not be used with other options to read or write
         tag values in the same command, but may be combined with options
         such -ext, -if, -r, -q and -v.

   Advanced options
    Among other things, the advanced options allow complex processing to be
    performed from a single command without the need for additional
    scripting. This may be particularly useful for implementations such as
    Windows drag-and-drop applications. These options may also be used to
    improve performance in multi-pass processing by reducing the overhead
    required to load exiftool for each invocation.

    -api *OPT[[^]=[VAL]]*
         Set ExifTool API option. *OPT* is an API option name. The option
         value is set to 1 if *=VAL* is omitted. If *VAL* is omitted, the
         option value is set to undef if "=" is used, or an empty string
         with "^=". See Image::ExifTool Options for a list of available API
         options. This overrides API options set via the config file.

    -common_args
         Specifies that all arguments following this option are common to
         all executed commands when -execute is used. This and the -config
         option are the only options that may not be used inside a -@
         *ARGFILE*. Note that by definition this option and its arguments
         MUST come after all other options on the command line.

    -config *CFGFILE*
         Load specified configuration file instead of the default
         ".ExifTool_config". If used, this option must come before all other
         arguments on the command line and applies to all -execute'd
         commands. The *CFGFILE* must exist relative to the current working
         directory or the exiftool application directory unless an absolute
         path is specified. Loading of the default config file may be
         disabled by setting *CFGFILE* to an empty string (ie. ""). See
         <https://exiftool.org/config.html> and config_files/example.config
         in the full ExifTool distribution for details about the
         configuration file syntax.

    -echo[*NUM*] *TEXT*
         Echo *TEXT* to stdout (-echo or -echo1) or stderr (-echo2). Text is
         output as the command line is parsed, before the processing of any
         input files. *NUM* may also be 3 or 4 to output text (to stdout or
         stderr respectively) after processing is complete. For -echo3 and
         -echo4, "${status}" may be used in the *TEXT* string to represent
         the numerical exit status of the command (see "EXIT STATUS").

    -efile[*NUM*][!] *ERRFILE*
         Save the names of files giving errors (*NUM* missing or 1), files
         that were unchanged (*NUM* is 2), files that fail the -if condition
         (*NUM* is 4), or any combination thereof by summing *NUM* (eg.
         -efile3 is the same has having both -efile and -efile2 options with
         the same *ERRFILE*). By default, file names are appended to any
         existing *ERRFILE*, but *ERRFILE* is overwritten if an exclamation
         point is added to the option (eg. -efile!). Saves the name of the
         file specified by the -srcfile option if applicable.

    -execute[*NUM*]
         Execute command for all arguments up to this point on the command
         line (plus any arguments specified by -common_args). The result is
         as if the commands were executed as separate command lines (with
         the exception of the -config and -use options which remain in
         effect for subsequent commands). Allows multiple commands to be
         executed from a single command line. *NUM* is an optional number
         that is echoed in the "{ready}" message when using the -stay_open
         feature. If a *NUM* is specified, the -q option no longer
         suppresses the output "{readyNUM}" message.

    -list_dir
         List directories themselves instead of their contents. This option
         effectively causes directories to be treated as normal files when
         reading and writing. For example, with this option the output of
         the "ls -la" command on Mac/Linux may be approximated by this
         exiftool command:

             exiftool -list_dir -T -ls-l -api systemtags -fast5 .* *

         (The -T option formats the output in tab-separated columns, -ls-l
         is a shortcut tag, the API SystemTags option is required to extract
         some necessary tags, and the -fast5 option is added for speed since
         only system tags are being extracted.)

    -srcfile *FMT*
         Specify a different source file to be processed based on the name
         of the original *FILE*. This may be useful in some special
         situations for processing related preview images or sidecar files.
         See the -w option for a description of the *FMT* syntax. Note that
         file name *FMT* strings for all options are based on the original
         *FILE* specified from the command line, not the name of the source
         file specified by -srcfile.

         For example, to copy metadata from NEF files to the corresponding
         JPG previews in a directory where other JPG images may exist:

             exiftool -ext nef -tagsfromfile @ -srcfile %d%f.jpg dir

         If more than one -srcfile option is specified, the files are tested
         in order and the first existing source file is processed. If none
         of the source files already exist, then exiftool uses the first
         -srcfile specified.

         A *FMT* of "@" may be used to represent the original *FILE*, which
         may be useful when specifying multiple -srcfile options (eg. to
         fall back to processing the original *FILE* if no sidecar exists).

         When this option is used, two special UserParam tags
         (OriginalFileName and OriginalDirectory) are generated to allow
         access to the original *FILE* name and directory.

    -stay_open *FLAG*
         If *FLAG* is 1 or "True" (case insensitive), causes exiftool keep
         reading from the -@ *ARGFILE* even after reaching the end of file.
         This feature allows calling applications to pre-load exiftool, thus
         avoiding the overhead of loading exiftool for each command. The
         procedure is as follows:

         1) Execute "exiftool -stay_open True -@ *ARGFILE*", where *ARGFILE*
         is the name of an existing (possibly empty) argument file or "-" to
         pipe arguments from the standard input.

         2) Write exiftool command-line arguments to *ARGFILE*, one argument
         per line (see the -@ option for details).

         3) Write "-execute\n" to *ARGFILE*, where "\n" represents a newline
         sequence. (Note: You may need to flush your write buffers here if
         using buffered output.) ExifTool will then execute the command with
         the arguments received up to this point, send a "{ready}" message
         to stdout when done (unless the -q or -T option is used), and
         continue trying to read arguments for the next command from
         *ARGFILE*. To aid in command/response synchronization, any number
         appended to the -execute option is echoed in the "{ready}" message.
         For example, "-execute613" results in "{ready613}". When this
         number is added, -q no longer suppresses the "{ready}" message.
         (Also, see the -echo3 and -echo4 options for additional ways to
         pass signals back to your application.)

         4) Repeat steps 2 and 3 for each command.

         5) Write "-stay_open\nFalse\n" (or "-stay_open\n0\n") to *ARGFILE*
         when done. This will cause exiftool to process any remaining
         command-line arguments then exit normally.

         The input *ARGFILE* may be changed at any time before step 5 above
         by writing the following lines to the currently open *ARGFILE*:

             -stay_open
             True
             -@
             NEWARGFILE

         This causes *ARGFILE* to be closed, and *NEWARGFILE* to be kept
         open. (Without the -stay_open here, exiftool would have returned to
         reading arguments from *ARGFILE* after reaching the end of
         *NEWARGFILE*.)

         Note: When writing arguments to a disk file there is a delay of up
         to 0.01 seconds after writing "-execute\n" before exiftool starts
         processing the command. This delay may be avoided by sending a CONT
         signal to the exiftool process immediately after writing
         "-execute\n". (There is no associated delay when writing arguments
         via a pipe with "-@ -", so the signal is not necessary when using
         this technique.)

    -userParam *PARAM[[^]=[VAL]]*
         Set user parameter. *PARAM* is an arbitrary user parameter name.
         This is an interface to the API UserParam option (see the
         Image::ExifTool Options documentation), and provides a method to
         access user-defined parameters in arguments to the -if and -p
         options as if they were any other tag. Appending a hash tag ("#")
         to *PARAM* (eg. "-userParam MyTag#=yes") also causes the parameter
         to be extracted as a normal tag in the UserParam group. Similar to
         the -api option, the parameter value is set to 1 if *=VAL* is
         omitted, undef if just *VAL* is omitted with "=", or an empty
         string if *VAL* is omitted with "^=".

             exiftool -p "$test from $filename" -userparam test=Hello FILE

   Advanced formatting feature
    An advanced formatting feature allows modification of the value of any
    tag interpolated within a -if or -p option argument, or a -tagsFromFile
    redirection string. Tag names within these strings are prefixed by a "$"
    symbol, and an arbitrary Perl expression may be applied to the tag value
    by placing braces around the tag name and inserting the expression after
    the name, separated by a semicolon (ie. "${TAG;EXPR}"). The expression
    acts on the value of the tag through the default input variable ($_),
    and has access to the full ExifTool API through the current ExifTool
    object ($self) and the tag key ($tag). It may contain any valid Perl
    code, including translation ("tr///") and substitution ("s///")
    operations, but note that braces within the expression must be balanced.
    The example below prints the camera Make with spaces translated to
    underlines, and multiple consecutive underlines replaced by a single
    underline:

        exiftool -p "${make;tr/ /_/;s/__+/_/g}" image.jpg

    An "@" may be added after the tag name to make the expression act on
    individual list items for list-type tags, simplifying list processing.
    Set $_ to undef to remove an item from the list. As an example, the
    following command returns all subjects not containing the string "xxx":

        exiftool -p "${subject@;$_=undef if /xxx/}" image.jpg

    A default expression of "tr(/\\?*:|"<>\0)()d" is assumed if the
    expression is empty (ie. "${TAG;}"). This removes the characters / \ ? *
    : | < > and null from the printed value. (These characters are illegal
    in Windows file names, so this feature is useful if tag values are used
    in file names.)

   Helper functions
    "DateFmt"

    Simplifies reformatting of individual date/time values. This function
    acts on a standard EXIF-formatted date/time value in $_ and formats it
    according to the specified format string (see the -d option). To avoid
    trying to reformat an already-formatted date/time value, a "#" must be
    added to the tag name (as in the example below) if the -d option is also
    used. For example:

        exiftool -p "${createdate#;DateFmt('%Y-%m-%d_%H%M%S')}" a.jpg

    "ShiftTime"

    Shifts EXIF-formatted date/time string by a specified amount. Start with
    a leading minus sign to shift backwards in time. See
    Image::ExifTool::Shift.pl for details about shift syntax. For example,
    to shift a date/time value back by one year:

        exiftool -p "${createdate;ShiftTime('-1:0:0 0')}" a.jpg

    "NoDups"

    Removes duplicate items from a list with a separator specified by the
    -sep option. This function is most useful when copying list-type tags.
    For example, the following command may be used to remove duplicate
    Keywords:

        exiftool -sep "##" "-keywords<${keywords;NoDups}" a.jpg

    The -sep option is necessary to split the string back into individual
    list items when writing to a list-type tag.

    An optional flag argument may be set to 1 to cause "NoDups" to set $_ to
    undef if no duplicates existed, thus preventing the file from being
    rewritten unnecessarily:

        exiftool -sep "##" "-keywords<${keywords;NoDups(1)}" a.jpg

    Note that function names are case sensitive.

WINDOWS UNICODE FILE NAMES
    In Windows, command-line arguments are specified using the current code
    page and are recoded automatically to the system code page. This
    recoding is not done for arguments in ExifTool arg files, so by default
    filenames in arg files use the system code page. Unfortunately, these
    code pages are not complete character sets, so not all file names may be
    represented.

    ExifTool 9.79 and later allow the file name encoding to be specified
    with "-charset filename=CHARSET", where "CHARSET" is the name of a valid
    ExifTool character set, preferably "UTF8" (see the -charset option for a
    complete list). Setting this triggers the use of Windows wide-character
    i/o routines, thus providing support for most Unicode file names (see
    note 4). But note that it is not trivial to pass properly encoded file
    names on the Windows command line (see
    <https://exiftool.org/faq.html#Q18> for details), so placing them in a
    UTF-8 encoded -@ argfile and using "-charset filename=utf8" is
    recommended if possible.

    A warning is issued if a specified filename contains special characters
    and the filename character set was not provided. However, the warning
    may be disabled by setting "-charset filename=""", and ExifTool may
    still function correctly if the system code page matches the character
    set used for the file names.

    When a directory name is provided, the file name encoding need not be
    specified (unless the directory name contains special characters), and
    ExifTool will automatically use wide-character routines to scan the
    directory.

    The filename character set applies to the *FILE* arguments as well as
    filename arguments of -@, -geotag, -o, -p, -srcfile, -tagsFromFile,
    -csv=, -j= and -*TAG*<=. However, it does not apply to the -config
    filename, which always uses the system character set. The "-charset
    filename=" option must come before the -@ option to be effective, but
    the order doesn't matter with respect to other options.

    Notes:

    1) FileName and Directory tag values still use the same encoding as
    other tag values, and are converted to/from the filename character set
    when writing/reading if specified.

    2) Unicode support is not yet implemented for other Windows-based
    systems like Cygwin.

    3) See "WRITING READ-ONLY FILES" below for a note about editing
    read-only files with Unicode names.

    4) Unicode file names with surrogate pairs (code points over U+FFFF)
    still cause problems.

WRITING READ-ONLY FILES
    In general, ExifTool may be used to write metadata to read-only files
    provided that the user has write permission in the directory. However,
    there are three cases where file write permission is also required:

    1) When using the -overwrite_original_in_place option.

    2) When writing only pseudo System tags (eg. FileModifyDate).

    3) On Windows if the file has Unicode characters in its name, and a) the
    -overwrite_original option is used, or b) the "_original" backup already
    exists.

    Hidden files in Windows behave as read-only files when attempting to
    write any real tags to the file -- an error is generated when using the
    -overwrite_original_in_place, otherwise writing should be successful and
    the hidden attribute will be removed. But the -if option may be used to
    avoid processing hidden files (provided Win32API::File is available):

        exiftool -if "$fileattributes !~ /Hidden/" ...

READING EXAMPLES
    exiftool -a -u -g1 a.jpg
         Print all meta information in an image, including duplicate and
         unknown tags, sorted by group (for family 1). For performance
         reasons, this command may not extract all available metadata.
         (Metadata in embedded documents, metadata extracted by external
         utilities, and metadata requiring excessive processing time may not
         be extracted). Add "-ee3" and "-api RequestAll=3" to the command to
         extract absolutely everything available.

    exiftool -common dir
         Print common meta information for all images in "dir". "-common" is
         a shortcut tag representing common EXIF meta information.

    exiftool -T -createdate -aperture -shutterspeed -iso dir > out.txt
         List specified meta information in tab-delimited column form for
         all images in "dir" to an output text file named "out.txt".

    exiftool -s -ImageSize -ExposureTime b.jpg
         Print ImageSize and ExposureTime tag names and values.

    exiftool -l -canon c.jpg d.jpg
         Print standard Canon information from two image files.

    exiftool -r -w .txt -common pictures
         Recursively extract common meta information from files in
         "pictures" directory, writing text output to ".txt" files with the
         same names.

    exiftool -b -ThumbnailImage image.jpg > thumbnail.jpg
         Save thumbnail image from "image.jpg" to a file called
         "thumbnail.jpg".

    exiftool -b -JpgFromRaw -w _JFR.JPG -ext NEF -r .
         Recursively extract JPG image from all Nikon NEF files in the
         current directory, adding "_JFR.JPG" for the name of the output JPG
         files.

    exiftool -a -b -W %d%f_%t%-c.%s -preview:all dir
         Extract all types of preview images (ThumbnailImage, PreviewImage,
         JpgFromRaw, etc.) from files in directory "dir", adding the tag
         name to the output preview image file names.

    exiftool -d "%r %a, %B %e, %Y" -DateTimeOriginal -S -s -ext jpg .
         Print formatted date/time for all JPG files in the current
         directory.

    exiftool -IFD1:XResolution -IFD1:YResolution image.jpg
         Extract image resolution from EXIF IFD1 information (thumbnail
         image IFD).

    exiftool "-*resolution*" image.jpg
         Extract all tags with names containing the word "Resolution" from
         an image.

    exiftool -xmp:author:all -a image.jpg
         Extract all author-related XMP information from an image.

    exiftool -xmp -b a.jpg > out.xmp
         Extract complete XMP data record intact from "a.jpg" and write it
         to "out.xmp" using the special "XMP" tag (see the Extra tags in
         Image::ExifTool::TagNames).

    exiftool -p "$filename has date $dateTimeOriginal" -q -f dir
         Print one line of output containing the file name and
         DateTimeOriginal for each image in directory "dir".

    exiftool -ee3 -p '$gpslatitude, $gpslongitude, $gpstimestamp' a.m2ts
         Extract all GPS positions from an AVCHD video.

    exiftool -icc_profile -b -w icc image.jpg
         Save complete ICC_Profile from an image to an output file with the
         same name and an extension of ".icc".

    exiftool -htmldump -w tmp/%f_%e.html t/images
         Generate HTML pages from a hex dump of EXIF information in all
         images from the "t/images" directory. The output HTML files are
         written to the "tmp" directory (which is created if it didn't
         exist), with names of the form "FILENAME_EXT.html".

    exiftool -a -b -ee -embeddedimage -W Image_%.3g3.%s file.pdf
         Extract embedded JPG and JP2 images from a PDF file. The output
         images will have file names like "Image_#.jpg" or "Image_#.jp2",
         where "#" is the ExifTool family 3 embedded document number for the
         image.

WRITING EXAMPLES
    Note that quotes are necessary around arguments which contain certain
    special characters such as ">", "<" or any white space. These quoting
    techniques are shell dependent, but the examples below will work in
    the Windows CMD shell.

    exiftool -Comment="This is a new comment" dst.jpg
         Write new comment to a JPG image (replaces any existing comment).

    exiftool -comment= -o newdir -ext jpg .
         Remove comment from all JPG images in the current directory,
         writing the modified images to a new directory.

    exiftool -keywords=EXIF -keywords=editor dst.jpg
         Replace existing keyword list with two new keywords ("EXIF" and
         "editor").

    exiftool -Keywords+=word -o newfile.jpg src.jpg
         Copy a source image to a new file, and add a keyword ("word") to
         the current list of keywords.

    exiftool -exposurecompensation+=-0.5 a.jpg
         Decrement the value of ExposureCompensation by 0.5 EV. Note that +=
         with a negative value is used for decrementing because the -=
         operator is used for conditional deletion (see next example).

    exiftool -credit-=xxx dir
         Delete Credit information from all files in a directory where the
         Credit value was "xxx".

    exiftool -xmp:description-de="k&uuml;hl" -E dst.jpg
         Write alternate language for XMP:Description, using HTML character
         escaping to input special characters.

    exiftool -all= dst.jpg
         Delete all meta information from an image. Note: You should NOT do
         this to RAW images (except DNG) since proprietary RAW image formats
         often contain information in the makernotes that is necessary for
         converting the image.

    exiftool -all= -comment="lonely" dst.jpg
         Delete all meta information from an image and add a comment back
         in. (Note that the order is important: -comment="lonely" -all=
         would also delete the new comment.)

    exiftool -all= --jfif:all dst.jpg
         Delete all meta information except JFIF group from an image.

    exiftool -Photoshop:All= dst.jpg
         Delete Photoshop meta information from an image (note that the
         Photoshop information also includes IPTC).

    exiftool -r -XMP-crss:all= DIR
         Recursively delete all XMP-crss information from images in a
         directory.

    exiftool "-ThumbnailImage<=thumb.jpg" dst.jpg
         Set the thumbnail image from specified file (Note: The quotes are
         necessary to prevent shell redirection).

    exiftool "-JpgFromRaw<=%d%f_JFR.JPG" -ext NEF -r .
         Recursively write JPEG images with filenames ending in "_JFR.JPG"
         to the JpgFromRaw tag of like-named files with extension ".NEF" in
         the current directory. (This is the inverse of the "-JpgFromRaw"
         command of the "READING EXAMPLES" section above.)

    exiftool -DateTimeOriginal-="0:0:0 1:30:0" dir
         Adjust original date/time of all images in directory "dir" by
         subtracting one hour and 30 minutes. (This is equivalent to
         "-DateTimeOriginal-=1.5". See Image::ExifTool::Shift.pl for
         details.)

    exiftool -createdate+=3 -modifydate+=3 a.jpg b.jpg
         Add 3 hours to the CreateDate and ModifyDate timestamps of two
         images.

    exiftool -AllDates+=1:30 -if "$make eq 'Canon'" dir
         Shift the values of DateTimeOriginal, CreateDate and ModifyDate
         forward by 1 hour and 30 minutes for all Canon images in a
         directory. (The AllDates tag is provided as a shortcut for these
         three tags, allowing them to be accessed via a single tag.)

    exiftool -xmp:city=Kingston image1.jpg image2.nef
         Write a tag to the XMP group of two images. (Without the "xmp:"
         this tag would get written to the IPTC group since "City" exists in
         both, and IPTC is preferred by default.)

    exiftool -LightSource-="Unknown (0)" dst.tiff
         Delete "LightSource" tag only if it is unknown with a value of 0.

    exiftool -whitebalance-=auto -WhiteBalance=tung dst.jpg
         Set "WhiteBalance" to "Tungsten" only if it was previously "Auto".

    exiftool -comment-= -comment="new comment" a.jpg
         Write a new comment only if the image doesn't have one already.

    exiftool -o %d%f.xmp dir
         Create XMP meta information data files for all images in "dir".

    exiftool -o test.xmp -owner=Phil -title="XMP File"
         Create an XMP data file only from tags defined on the command line.

    exiftool "-ICC_Profile<=%d%f.icc" image.jpg
         Write ICC_Profile to an image from a ".icc" file of the same name.

    exiftool -hierarchicalkeywords="{keyword=one,children={keyword=B}}"
         Write structured XMP information. See
         <https://exiftool.org/struct.html> for more details.

    exiftool -trailer:all= image.jpg
         Delete any trailer found after the end of image (EOI) in a JPEG
         file. A number of digital cameras store a large PreviewImage after
         the JPEG EOI, and the file size may be reduced significantly by
         deleting this trailer. See the JPEG Tags documentation for a list
         of recognized JPEG trailers.

COPYING EXAMPLES
    These examples demonstrate the ability to copy tag values between files.

    exiftool -tagsFromFile src.cr2 dst.jpg
         Copy the values of all writable tags from "src.cr2" to "dst.jpg",
         writing the information to same-named tags in the preferred groups.

    exiftool -TagsFromFile src.jpg -all:all dst.jpg
         Copy the values of all writable tags from "src.jpg" to "dst.jpg",
         preserving the original tag groups.

    exiftool -all= -tagsfromfile src.jpg -exif:all dst.jpg
         Erase all meta information from "dst.jpg" image, then copy EXIF
         tags from "src.jpg".

    exiftool -exif:all= -tagsfromfile @ -all:all -unsafe bad.jpg
         Rebuild all EXIF meta information from scratch in an image. This
         technique can be used in JPEG images to repair corrupted EXIF
         information which otherwise could not be written due to errors. The
         "Unsafe" tag is a shortcut for unsafe EXIF tags in JPEG images
         which are not normally copied. See the tag name documentation for
         more details about unsafe tags.

    exiftool -Tagsfromfile a.jpg out.xmp
         Copy meta information from "a.jpg" to an XMP data file. If the XMP
         data file "out.xmp" already exists, it will be updated with the new
         information. Otherwise the XMP data file will be created. Only
         metadata-only files may be created like this (files containing
         images may be edited but not created). See "WRITING EXAMPLES" above
         for another technique to generate XMP files.

    exiftool -tagsFromFile a.jpg -XMP:All= -ThumbnailImage= -m b.jpg
         Copy all meta information from "a.jpg" to "b.jpg", deleting all XMP
         information and the thumbnail image from the destination.

    exiftool -TagsFromFile src.jpg -title -author=Phil dst.jpg
         Copy title from one image to another and set a new author name.

    exiftool -TagsFromFile a.jpg -ISO -TagsFromFile b.jpg -comment dst.jpg
         Copy ISO from one image and Comment from another image to a
         destination image.

    exiftool -tagsfromfile src.jpg -exif:all --subifd:all dst.jpg
         Copy only the EXIF information from one image to another, excluding
         SubIFD tags.

    exiftool "-FileModifyDate<DateTimeOriginal" dir
         Use the original date from the meta information to set the same
         file's filesystem modification date for all images in a directory.
         (Note that "-TagsFromFile @" is assumed if no other -TagsFromFile
         is specified when redirecting information as in this example.)

    exiftool -TagsFromFile src.jpg "-xmp:all<all" dst.jpg
         Copy all possible information from "src.jpg" and write in XMP
         format to "dst.jpg".

    exiftool "-Description<${FileName;s/\.[^.]*$//}" dir
         Set the image Description from the file name after removing the
         extension. This example uses the "Advanced formatting feature" to
         perform a substitution operation to remove the last dot and
         subsequent characters from the file name.

    exiftool -@ iptc2xmp.args -iptc:all= a.jpg
         Translate IPTC information to XMP with appropriate tag name
         conversions, and delete the original IPTC information from an
         image. This example uses iptc2xmp.args, which is a file included
         with the ExifTool distribution that contains the required arguments
         to convert IPTC information to XMP format. Also included with the
         distribution are xmp2iptc.args (which performs the inverse
         conversion) and a few more .args files for other conversions
         between EXIF, IPTC and XMP.

    exiftool -tagsfromfile %d%f.CR2 -r -ext JPG dir
         Recursively rewrite all "JPG" images in "dir" with information
         copied from the corresponding "CR2" images in the same directories.

    exiftool "-keywords+<make" image.jpg
         Add camera make to list of keywords.

    exiftool "-comment<ISO=$exif:iso Exposure=${shutterspeed}" dir
         Set the Comment tag of all images in "dir" from the values of the
         EXIF:ISO and ShutterSpeed tags. The resulting comment will be in
         the form "ISO=100 Exposure=1/60".

    exiftool -TagsFromFile src.jpg -icc_profile dst.jpg
         Copy ICC_Profile from one image to another.

    exiftool -TagsFromFile src.jpg -all:all dst.mie
         Copy all meta information in its original form from a JPEG image to
         a MIE file. The MIE file will be created if it doesn't exist. This
         technique can be used to store the metadata of an image so it can
         be inserted back into the image (with the inverse command) later in
         a workflow.

    exiftool -o dst.mie -all:all src.jpg
         This command performs exactly the same task as the command above,
         except that the -o option will not write to an output file that
         already exists.

    exiftool -b -jpgfromraw -w %d%f_%ue.jpg -execute -b -previewimage -w
    %d%f_%ue.jpg -execute -tagsfromfile @ -srcfile %d%f_%ue.jpg
    -overwrite_original -common_args --ext jpg DIR
         [Advanced] Extract JpgFromRaw or PreviewImage from all but JPG
         files in DIR, saving them with file names like "image_EXT.jpg",
         then add all meta information from the original files to the
         extracted images. Here, the command line is broken into three
         sections (separated by -execute options), and each is executed as
         if it were a separate command. The -common_args option causes the
         "--ext jpg DIR" arguments to be applied to all three commands, and
         the -srcfile option allows the extracted JPG image to be the source
         file for the third command (whereas the RAW files are the source
         files for the other two commands).

RENAMING EXAMPLES
    By writing the "FileName" and "Directory" tags, files are renamed and/or
    moved to new directories. This can be particularly useful and powerful
    for organizing files by date when combined with the -d option. New
    directories are created as necessary, but existing files will not be
    overwritten. The format codes %d, %f and %e may be used in the new file
    name to represent the directory, name and extension of the original
    file, and %c may be used to add a copy number if the file already exists
    (see the -w option for details). Note that if used within a date format
    string, an extra '%' must be added to pass these codes through the
    date/time parser. (And further note that in a Windows batch file, all
    '%' characters must also be escaped, so in this extreme case "%%%%f" is
    necessary to pass a simple "%f" through the two levels of parsing.) See
    <https://exiftool.org/filename.html> for additional documentation and
    examples.

    exiftool -filename=new.jpg dir/old.jpg
         Rename "old.jpg" to "new.jpg" in directory "dir".

    exiftool -directory=%e dir
         Move all files from directory "dir" into directories named by the
         original file extensions.

    exiftool "-Directory<DateTimeOriginal" -d %Y/%m/%d dir
         Move all files in "dir" into a directory hierarchy based on year,
         month and day of "DateTimeOriginal". eg) This command would move
         the file "dir/image.jpg" with a "DateTimeOriginal" of "2005:10:12
         16:05:56" to "2005/10/12/image.jpg".

    exiftool -o . "-Directory<DateTimeOriginal" -d %Y/%m/%d dir
         Same effect as above except files are copied instead of moved.

    exiftool "-filename<%f_${model;}.%e" dir
         Rename all files in "dir" by adding the camera model name to the
         file name. The semicolon after the tag name inside the braces
         causes characters which are invalid in Windows file names to be
         deleted from the tag value (see the "Advanced formatting feature"
         for an explanation).

    exiftool "-FileName<CreateDate" -d %Y%m%d_%H%M%S%%-c.%%e dir
         Rename all images in "dir" according to the "CreateDate" date and
         time, adding a copy number with leading '-' if the file already
         exists ("%-c"), and preserving the original file extension (%e).
         Note the extra '%' necessary to escape the filename codes (%c and
         %e) in the date format string.

    exiftool -r "-FileName<CreateDate" -d %Y-%m-%d/%H%M_%%f.%%e dir
         Both the directory and the filename may be changed together via the
         "FileName" tag if the new "FileName" contains a '/'. The example
         above recursively renames all images in a directory by adding a
         "CreateDate" timestamp to the start of the filename, then moves
         them into new directories named by date.

    exiftool "-FileName<${CreateDate}_$filenumber.jpg" -d %Y%m%d -ext jpg .
         Set the filename of all JPG images in the current directory from
         the CreateDate and FileNumber tags, in the form
         "20060507_118-1861.jpg".

GEOTAGGING EXAMPLES
    ExifTool implements geotagging via 3 special tags: Geotag (which for
    convenience is also implemented as an exiftool option), Geosync and
    Geotime. The examples below highlight some geotagging features. See
    <https://exiftool.org/geotag.html> for additional documentation.

    exiftool -geotag track.log a.jpg
         Geotag an image ("a.jpg") from position information in a GPS track
         log ("track.log"). Since the "Geotime" tag is not specified, the
         value of DateTimeOriginal is used for geotagging. Local system time
         is assumed unless DateTimeOriginal contains a timezone.

    exiftool -geotag t.log -geotime="2009:04:02 13:41:12-05:00" a.jpg
         Geotag an image with the GPS position for a specific time.

    exiftool -geotag log.gpx "-xmp:geotime<createdate" dir
         Geotag all images in directory "dir" with XMP tags instead of EXIF
         tags, based on the image CreateDate.

    exiftool -geotag a.log -geosync=-20 dir
         Geotag images in directory "dir", accounting for image timestamps
         which were 20 seconds ahead of GPS.

    exiftool -geotag a.log -geosync=1.jpg -geosync=2.jpg dir
         Geotag images using time synchronization from two previously
         geotagged images (1.jpg and 2.jpg), synchronizing the image and GPS
         times using a linear time drift correction.

    exiftool -geotag a.log "-geotime<${createdate}+01:00" dir
         Geotag images in "dir" using CreateDate with the specified
         timezone. If CreateDate already contained a timezone, then the
         timezone specified on the command line is ignored.

    exiftool -geotag= a.jpg
         Delete GPS tags which may have been added by the geotag feature.
         Note that this does not remove all GPS tags -- to do this instead
         use "-gps:all=".

    exiftool -xmp:geotag= a.jpg
         Delete XMP GPS tags which were added by the geotag feature.

    exiftool -xmp:geotag=track.log a.jpg
         Geotag an image with XMP tags, using the time from
         DateTimeOriginal.

    exiftool -geotag a.log -geotag b.log -r dir
         Combine multiple track logs and geotag an entire directory tree of
         images.

    exiftool -geotag "tracks/*.log" -r dir
         Read all track logs from the "tracks" directory.

    exiftool -p gpx.fmt -d %Y-%m-%dT%H:%M:%SZ dir > out.gpx
         Generate a GPX track log from all images in directory "dir". This
         example uses the "gpx.fmt" file included in the full ExifTool
         distribution package and assumes that the images in "dir" have all
         been previously geotagged.

PIPING EXAMPLES
    type a.jpg | exiftool -
         Extract information from stdin.

    exiftool image.jpg -thumbnailimage -b | exiftool -
         Extract information from an embedded thumbnail image.

    type a.jpg | exiftool -iptc:keywords+=fantastic - > b.jpg
         Add an IPTC keyword in a pipeline, saving output to a new file.

    curl -s http://a.domain.com/bigfile.jpg | exiftool -fast -
         Extract information from an image over the internet using the cURL
         utility. The -fast option prevents exiftool from scanning for
         trailer information, so only the meta information header is
         transferred.

    exiftool a.jpg -thumbnailimage -b | exiftool -comment=wow - | exiftool
    a.jpg "-thumbnailimage<=-"
         Add a comment to an embedded thumbnail image. (Why anyone would
         want to do this I don't know, but I've included this as an example
         to illustrate the flexibility of ExifTool.)

INTERRUPTING EXIFTOOL
    Interrupting exiftool with a CTRL-C or SIGINT will not result in
    partially written files or temporary files remaining on the hard disk.
    The exiftool application traps SIGINT and defers it until the end of
    critical processes if necessary, then does a proper cleanup before
    exiting.

EXIT STATUS
    The exiftool application exits with a status of 0 on success, or 1 if an
    error occurred, or 2 if all files failed the -if condition (for any of
    the commands if -execute was used).

AUTHOR
    Copyright 2003-2021, Phil Harvey

    This is free software; you can redistribute it and/or modify it under
    the same terms as Perl itself.

SEE ALSO
    Image::ExifTool(3pm), Image::ExifTool::TagNames(3pm),
    Image::ExifTool::Shortcuts(3pm), Image::ExifTool::Shift.pl

__HELP__

    my $dir = $ENV{PAR_GLOBAL_TEMP} || $ENV{PAR_TEMP} || $ENV{TMP} || $ENV{TEMP} || '/tmp';
    my $docFile = "$dir/exiftool_${version}_doc.txt";
    unless (-e $docFile) {
        # try backslashes first if it seems we may be running in cmd.exe
        $docFile =~ tr/\//\\/ if $ENV{ComSpec} or $docFile =~ /\\/;
        unless (open(TEMP, ">$docFile") or
            ($docFile =~ tr/\/\\/\\\// and open(TEMP, ">$docFile")) or  # try forward slash
            (CreateDirectory($docFile) and open(TEMP, ">$docFile")))    # try creating dir
        {
            warn "Error creating temp file $docFile\n";
            warn "So ExifTool can't print the help documentation.\n";
            return;
        }
        my $ok = print TEMP $help;
        close TEMP;
        unless ($ok) {
            unlink $docFile;
            warn "Error writing temp file $docFile\n";
        }
    }
    system(qq{more < "$docFile"}) and warn "Error running more $docFile\n";
}

# end
