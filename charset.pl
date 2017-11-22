use strict;
use warnings;
use 5.010;
use open qw/:std :utf8/;

# SYNOPSIS
# declares code for a hash storing a charset table

@ARGV = 'sada';

while (<>) {
    chomp;
    s/^\s+//;

    # CHAR, LOWER num, UPPER num
    my @chr_set = split /\s+/;

    if (@chr_set == 3) {
        # LOWER chars 
        # my $hex = sprintf("%02X", $chr_set[1]);
        # say " " x 4, "'", lc $chr_set[0], "' =>  ", '"\x{' . $hex . '}",';
        
        # UPPER chars
        my $hex = sprintf("%02X", $chr_set[2]);
        say " " x 4, qq('$chr_set[0]' =>  ), '"\x{' . $hex . '}",';
    }
}
