#!/usr/bin/perl

use strict;
use warnings;

while(defined(my $line=<STDIN>)) {
    $line=~s/\&\s*amp\s*\;/\&/g;
    $line=~s/\&\s*lt\s*\;/\</g;
    $line=~s/\&\s*gt\s*\;/\>/g;
    $line=~s/\:\s*\)\s*\)/\:\)\)/g;
    $line=~s/\:\s*\)/\:\)/g;
    $line=~s/\;\s*\)/\;\)/g;
    $line=~s/\:\s*([pPDd]) /\:$1 /g;
    $line=~s/\:\s*([pPDd])\s*\n/\:$1\n/g;
    $line=~s/\:\s*s/\:s/g;
    $line=~s/\:\s*\(\s*\(/\:\(\(/g;
    $line=~s/\:\s*\(/\:\(/g;
    $line=~s/\:\s*\|/\:\|/g;
    $line=~s/\:\s*\*/\:\*/g;
    $line=~s/\:\s*\'\s*\)/\:\'\)/g;
    $line=~s/\:\s*\'\s*\(/\:\'\(/g;
    $line=~s/\:p /\:P /g;
    $line=~s/\:p\s*\n/\:P\n/g;
    $line=~s/\:d /\:D /g;
    $line=~s/\:d\s*\n/\:D\n/g;

    print $line;
}



