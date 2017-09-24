#! /usr/bin/perl

use strict;
use Getopt::Long "GetOptions";

my $usage = "
-----
create-dictionary.pl < CORPUS.tok [OPTIONS] > CORPUS.dict
-----
Extract dictionary of a corpus (should be already tokenized).
Writes out words ordered by frequency.
Options:
    --minfreq=INTEGER     Discard words with less than INTEGER occurrences
    --maxfreq=INTEGER     Discard words with more than INTEGER occurrences
    --printfreq=INTEGER   Prints out frequencies.
    --morfessor           Prints out 'frequency word' (Morfessor format)
#
#
";

my $debug = '';
my $printfreq = '';
my $minfreq = 0;
my $maxfreq = 0;
my $morfessor = '';

GetOptions ('debug' => \$debug,
            'printfreq' => \$printfreq,
            'minfreq=i' => \$minfreq,
            'maxfreq=i' => \$maxfreq,
	        'morfessor' => \$morfessor,
            ) || die "$0:\n$usage";


###########################################

my %DICT = ();
my $nbSnt=0;

while (my $line = <STDIN>) {
    chomp $line;
    
	$nbSnt++;
    if($nbSnt%100000 == 0) { print STDERR "processed lines: $nbSnt\n"; }

    foreach my $token (split('\s+', $line)) {
        $DICT{$token}++;
	}
}

	
foreach my $word (sort { $DICT{$b} <=> $DICT{$a} } keys %DICT) {

    next if($maxfreq>0 && $DICT{$word}>$maxfreq);
    
    last if($DICT{$word}<$minfreq);
    
    if($morfessor) {
	print $DICT{$word}, " ", $word, "\n";
    } else {
	print $word;
	print "\t", $DICT{$word} if($printfreq);
	print "\n";
    }
}


