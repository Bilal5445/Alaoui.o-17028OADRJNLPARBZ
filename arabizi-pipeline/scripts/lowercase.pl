#!/usr/bin/perl -w

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

while(defined($line=<STDIN>)) {
    $line=lc($line);
    print $line;
};
