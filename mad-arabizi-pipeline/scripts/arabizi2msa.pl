#! /usr/bin/perl

use strict;
use lib ('./scripts');
use Arabizisubs;

my $match_length = 2;
my $print_derivation = 0;
my $pre_process = 1;
my $stack_limit = 10;
my $lm_order = 3;
my $OISTERHOME = $ENV{'OISTERHOME'};
my $srilm_lm = 'path/to/3gram/arabic/lm';
my %parameters;
my %features;
$parameters{'lm_cap'} = 0;
$parameters{'lm_order'} = $lm_order;
my @lm_srilm_ids;
$features{'lm_weight'} = 1;
$features{0} = 1;
my %feature_name2id;
$feature_name2id{'lm_weight'} = 0;
my $src_language_index = 0;
my %dummy_hash;

# fill arabizi_map from model file ptbale (ie a file that maps arabizi letters to arabic letters)
my $arabizi_pt_file = 'models/ptable'; # e.g. constructed from LDC2013E125
my %arabizi_map; # a hash that contains possible character replacements for each Arabizi character
open(F, "<$arabizi_pt_file") || die("can't open file $arabizi_pt_file: $!\n");
while(defined(my $line = <F>)) {
    chomp($line);
    my($f, $e, @rest) = split(/ \|\|\| /o, $line);
    # print STDOUT "$f is associated to $e \n";
    # print STDOUT "$f is associated to ", sprintf("%s", $e), "\n";
    $arabizi_map{$f}{$e} = 1;    
}
close(F);

# fill vocabulary from the arabic dictionary in the model file arabic-dict (ie a long list (~7mega) of msa arabic word taken from the news)
my $vocab_file = $ARGV[1];
my %vocab;
open(F, "<$vocab_file") || die("can't open file $vocab_file: $!\n");
while(defined(my $line=<F>)) {
    chomp($line);
    $vocab{$line} = 1;
}
close(F);

# loop on STDIN (ie the arabizi dictionary extracted from the input text: ie : a list of arabizi word as found in the input text)
# my $nbl=0;
while(defined(my $line=<STDIN>)) {

    # trace every 50 lines processed
    # $nbl++;
    # if($nbl%50 == 0) { print STDERR "line $nbl..."; };
    # print STDOUT "line $nbl... \n";
    # print STDOUT "$line... \n";
    
    # clean line
    chomp($line);
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;

    # split over spaces
    my @tokens_orig = split(/ /o, $line);
=pod
    for(my $i = 0; $i < @tokens_orig; $i ++) {
        print STDOUT "tokens_orig $i $tokens_orig[$i]... \n";
    }
=cut

    # pre-process align word using space (eg: "tkharbik" becomes "t k h a r b i k")
    # print STDOUT "before pre_process : $line ... \n";
    if($pre_process) {
        $line = &Arabizisubs::preprocess($line);
    }
    # print STDOUT "after pre_process : $line ... \n";

    #
    my @tokens = split(/ SEP /o, $line);
    my $length = @tokens;
    if($length != scalar(@tokens_orig)) {
        print STDERR "nb token mismatch:\nORIG: ", join(" ",@tokens_orig), "\n";
        print STDERR "PROC: ", join(" ",@tokens), "\n ******** EXITING!!! ******** \n\n\n";
        die;
    }
    
    # generate all possible Arabic transliterated of an Arabizi word (context doesn't matter here)
    my @cn = ();
    my %msa_substrings = ();
    for(my $i = 0; $i < @tokens; $i ++) {
        # print STDOUT "token : $tokens[$i] \n";
        &Arabizisubs::arabizi_msa_candidates($tokens[$i], \%arabizi_map, \@{ $cn[$i] }, \%msa_substrings);
        foreach my $msa_substring (keys %msa_substrings) {
            print "$msa_substrings{$msa_substring} = $msa_substring\n";   
        }

        #
        # print "cn array size: ", scalar @{ $cn[$i] }, "\n";
        # print "msa_substring hash size: ", scalar keys %msa_substrings, "\n";
    }
    
    # create confusion network (CN) containing transliterated words that are in the Arabic vocabulary, otherwise the Arabizi word itself
    my @cn_lm = ();
    for(my $i = 0; $i<@tokens; $i++) {
        for(my $j = 0; $j<@{ $cn[$i] }; $j++) {
            my($msa_token, $derivations) = split(/\t/, $cn[$i][$j]);
            if(exists($vocab{$msa_token})) {
                push(@{ $cn_lm[$i] },$msa_token);                
            }
        }
        if(!defined($cn_lm[$i]) || @{ $cn_lm[$i] }==0) {
            my $arabizi_string=$tokens[$i];
            $arabizi_string=~s/ +//g;
            push(@{ $cn_lm[$i] },$arabizi_string);
        }
    }
    $cn_lm[$length][0]='</s>';

    my $print_CN=0;
    if($print_CN) {
        for(my $i=0; $i<@cn_lm; $i++) {
            for(my $j=0; $j<@{ $cn_lm[$i] }; $j++) {
                print "cn_lm[$i][$j]=$cn_lm[$i][$j]\n";
            }
        }
    }

    my @stack;
    for(my $i=0; $i < @tokens; $i ++) {
        my $arabizi_string = $tokens_orig[$i];
        $arabizi_string =~s/ +//g;
        # print "$arabizi_string $arabizi_string 1";
        print "arabizi_string $arabizi_string 1 \n";
        for(my $j=0; $j<@{ $cn[$i] }; $j++) {
            my($msa_token,$derivations)=split(/\t/,$cn[$i][$j]);
            if(exists($vocab{$msa_token})) {
                # print " $msa_token 1";
                print "msa_token $msa_token 1 \n";
            }
        }
        print "\n";
    }
=pod
=cut
}