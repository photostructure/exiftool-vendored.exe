#------------------------------------------------------------------------------
# File:         HashProgress.pm
#
# Description:  Report ImageDataHash progress (exiftool-vendored patch)
#
# Notes:        Wraps the image data digest when the ImageHashProgress API
#               option is set to a number of seconds (fractions need
#               Time::HiRes). While image data is hashed, prints
#               "{progress:BYTES}" to stderr at most once per that many
#               seconds, where BYTES counts the bytes hashed so far for the
#               current file. A caller that runs ExifTool as a child process
#               can then tell a slow read from a stalled one.
#
# Revisions:    2026-09-24 - McEachen created under ExifTool license
#------------------------------------------------------------------------------

package Image::ExifTool::HashProgress;

use strict;

my $now = eval { require Time::HiRes; \&Time::HiRes::time } || sub { time };

sub new($$$)
{
    my ($class, $digest, $interval) = @_;
    return bless {
        Digest   => $digest,
        Interval => $interval,
        Bytes    => 0,
        Reported => $now->(),
    }, $class;
}

sub add($@)
{
    my $self = shift;
    $$self{Digest}->add(@_);
    $$self{Bytes} += length $_ foreach @_;
    if ($now->() - $$self{Reported} >= $$self{Interval}) {
        $$self{Reported} = $now->();
        print STDERR "{progress:$$self{Bytes}}\n";
    }
    return $self;
}

sub hexdigest($)
{
    my $self = shift;
    return $$self{Digest}->hexdigest;
}

1;  # end
