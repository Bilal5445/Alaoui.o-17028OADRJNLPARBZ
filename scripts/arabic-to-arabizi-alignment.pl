#! /usr/bin/perl

use strict;
use Getopt::Long;

my $usage = "
-----
$0 --arabizi=FILE --arabic=FILE > arabizi-arabic-word-pairs
-----
#
# Required:
# --arabizi     : Arabizi corpus
# --arabic      : Arabic transliteration (same number of lines, maybe different number of words)
#
# Optional:
# --map         : Add the newly extracted word pairs to this map (in disambig format)
# --bitext      : Suffix of bitext to print out (bitext.arabizi, bitext.arabic)
";

# my $MIN_RATIO = 0.5; why are we constraining the size to no be too much smaller ?
my $MIN_RATIO = 0.33;
# my $MAX_RATIO = 2.0;
my $MAX_RATIO = 3.0;

my $BACKOFF = 0;
my $PROBNEW = 0.999;
my $PROBMAP = 0.001;

my $AZ_file = '';
my $AR_file = '';
my $map_file = '';
my $bitext = '';
my $debug = 'true';

GetOptions ('arabizi=s' => \$AZ_file,
            'arabic=s' => \$AR_file,
            'mapfile=s' => \$map_file,
            'bitext=s' => \$bitext,
            'debug' => \$debug);

############################

if($AZ_file eq "") { die "$usage\n\nPlease specify the Arabizi file!\n"; }
open(AZ, $AZ_file) or die "Cannot open $AZ_file : ($!)\n";

if($AR_file eq "") { die "$usage\n\nPlease specify the Arabic file!\n"; }
open(AR, $AR_file) or die "Cannot open $AR_file : ($!)\n";

print STDERR "--
BACKOFF:$BACKOFF
PROBNEW:$PROBNEW
PROBMAP:$PROBMAP
--
";

if($bitext ne "") {
    open(BITEXT_AZ, ">$bitext.arabizi") or die "Cannot open $bitext.arabizi : ($!)\n";
    open(BITEXT_AR, ">$bitext.arabic")  or die "Cannot open $bitext.arabic : ($!)\n";
}

my %AZ_to_AR = ();

my $nbl = 0;
while (my $AZ_line = <AZ>) {
    my $AR_line = <AR> or die "Arabizi and Arabic files must have same number of lines!\n";

    $nbl++;
    
    chomp $AZ_line;
    chomp $AR_line;

    $AZ_line =~ s/^ +//; $AZ_line =~ s/ +$//;
    $AR_line =~ s/^ +//; $AR_line =~ s/ +$//;

    # why are we splitting the line into many words if any
    print STDERR "---\n";
    # my @AZ_tokens = split(/ +/, $AZ_line);
    my @AZ_tokens = ($AZ_line);
    print STDERR "AZ : $AZ_tokens[0]\n";
    # my @AR_tokens = split(/ +/, $AR_line);
    my @AR_tokens = ($AR_line);
    print STDERR "AR : $AR_tokens[0]\n";

    my $length = scalar(@AZ_tokens);
    if($length != scalar(@AR_tokens)) {
        print STDERR "number of words mismatch at line $nbl. Skipping\n";
        if($bitext ne "") {
            print STDERR "here";
            print BITEXT_AZ $AZ_line, "\n";
            print BITEXT_AR $AR_line, "\n";
        }
        next;
    }

    for(my $i = 0; $i < $length; $i ++) {
        my $AZ_tok = $AZ_tokens[$i];
        my $AR_tok = $AR_tokens[$i];
        my $AZ_length = length($AZ_tok);
        my $AR_length = length($AR_tok);

        # containing latin letters & digits ?
        # this code snipet check if token does not contains alphanumeric not punctiontions (but why the 'm' ?)
        if($AR_tok !~ m/[a-zA-Z0-9.,;:]/) {
            $AR_length = $AR_length / 2;
        
            print STDERR "divide per 2 ?\n";
        }

        #
        my $ratio = $AZ_length / $AR_length;
        if($MIN_RATIO <= $ratio && $ratio <= $MAX_RATIO) {
            $AZ_to_AR{$AZ_tok}{$AR_tok}++;
            print STDERR "ratio ?\n";
        }

        #
        if($bitext ne "") {
            print STDERR "here 2";
            print BITEXT_AZ $AZ_tok, "\n";
            print BITEXT_AR $AR_tok, "\n";
        }
    }
}

if($debug) {
    foreach my $AZ_word (sort keys (%AZ_to_AR)) {
        print STDERR "\n---\n $AZ_word\n";
        my %translations = %{$AZ_to_AR{$AZ_word}};
        foreach my $AR_word (sort keys %translations) {
            print STDERR "$AR_word ($translations{$AR_word})\n";
        }
    }
}


if($map_file ne "") {
    open(MAP, $map_file) or die "Cannot open mapfile $map_file : ($!)\n";
}

while (my $line = <MAP>) {
    chomp $line;
    my @fields = split(' ', $line);
    my $AZ_word = shift(@fields);
    
    my @fields_new = ();

    my %newWords = ();
    if(exists($AZ_to_AR{$AZ_word})) {
        foreach my $AR_word (sort keys %{$AZ_to_AR{$AZ_word}}) {
            push(@fields_new, $AR_word);
            push(@fields_new, $PROBNEW);
            $newWords{$AR_word} = 1;
        }
    }

    # if BACKOFF is active, add CM (char-level) transliterations only if no transliterations are available for the current word
    if(!$BACKOFF || scalar(@fields_new) == 0) {
        while(scalar(@fields>=2)) {
            my $word = shift(@fields);
            my $score = shift(@fields);
            if(!exists($newWords{$word})) {
                push(@fields_new, $word);
                push(@fields_new, $PROBMAP);
            }
        }
    }
    
    # replacing spaces by - so disambig can keep sentences together (will be fixed downstreamed at postprocessing)
    s/ /-/g for @fields_new;

    # DBG
    print STDERR "fields_new size : " . scalar(@fields_new) . "\n";
    foreach $a (@fields_new){
        print STDERR "value of a: $a\n";
    }

    #
    print $AZ_word, "\t", join(" ", @fields_new), "\n";
}











