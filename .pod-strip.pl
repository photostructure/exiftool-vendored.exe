#!/usr/bin/env perl

# This script will strip the POD from a file and overwrite the file with the
# stripped content.

use Pod::Strip; # install with `cpan Pod::Strip`

my $content;
my $filename = shift;
open(my $fh, '<', $filename) or die("cannot open file $filename");
{
    local $/;
    $content = <$fh>;
}
close($fh);

my $p=Pod::Strip->new;
my $podless;
$p->output_string(\$podless);
$p->parse_string_document($content);

open(my $fh2, ">", $filename) or die("cannot write file $filename");
print($fh2 $podless);
close($fh2);