#! /usr/bin/perl

use strict;

my $use_lm_str = $ARGV[0];
my $vocab_file = $ARGV[1];

my $MAX_WORD_LENGTH = 12;
my $match_length=2;

my $print_derivation=0;
my $pre_process=1;
my $stack_limit=10;
my $lm_order=3;
my $use_lm=0;

my $OISTERHOME=$ENV{'OISTERHOME'};

my $arabizi_pt_file='models/ptable'; # e.g. constructed from LDC2013E125
my $srilm_lm='path/to/3gram/arabic/lm';

my %parameters;
my %features;
$parameters{'lm_cap'}=0;
$parameters{'lm_order'}=$lm_order;
my @lm_srilm_ids;
if($use_lm) {
    $lm_srilm_ids[0]=&load_lm_file($srilm_lm,\%parameters);
}
$features{'lm_weight'}=1;
$features{0}=1;
my %feature_name2id;
$feature_name2id{'lm_weight'}=0;
 
my $src_language_index=0;

my %dummy_hash;

my %arabizi_map; # contains possible character replacements for each Arabizi character
open(F,"<$arabizi_pt_file")||die("can't open file $arabizi_pt_file: $!\n");
while(defined(my $line=<F>)) {
    chomp($line);
    my($f,$e,@rest)=split(/ \|\|\| /o,$line);
    $arabizi_map{$f}{$e}=1;    
}
close(F);

# models/arabic-dict
my %vocab;
open(F,"<$vocab_file")||die("can't open file $vocab_file: $!\n");
while(defined(my $line=<F>)) {
    chomp($line);
    $vocab{$line}=1;
}
close(F);

my $nbl=0;
while(defined(my $line=<STDIN>)) {
    $nbl++;
    if($nbl%50==0) { print STDERR "line $nbl..."; };
    #print STDERR "line $line \n";
    
    chomp($line);
    $line=~s/^\s+//;
    $line=~s/\s+$//;

    my @tokens_orig=split(/ /o,$line);

    if($pre_process) {
        $line=&preprocess($line);
    }

    my %msa_substrings = ();
    my @tokens = split(/ SEP /o, $line);
    # print STDERR "line: ", $line, "\n";
    # print STDERR "tokens: ", $tokens[0], "\n";
    
    my $length = @tokens;
    if($length != scalar(@tokens_orig)) {
        print STDERR "nb token mismatch:\nORIG: ", join(" ",@tokens_orig), "\n";
        print STDERR "PROC: ", join(" ",@tokens), "\n ******** EXITING!!! ******** \n\n\n";
        die;
    }
    
    my @cn = ();

    # generate ALL POSSIBLE Arabic transliterated of an Arabizi word (context doesn't matter here)
    # for that purpose, we use only the models/ptable (mapper between arabizi letter and arabic letter)
    # models\arabic-dict is used in further steps
    for(my $i = 0; $i < @tokens; $i++) {
        # eg : $tokens[$i] = s m e 3 t i
        &arabizi_msa_candidates($tokens[$i], \%arabizi_map, \@{ $cn[$i] }, \%msa_substrings);
        # print STDERR "size hash msa_substrings: ", scalar keys %msa_substrings, "\n";
    }
    # print STDERR "size hash msa_substrings: ", scalar keys %msa_substrings, "\n";
    # print STDERR "size array cn: ", scalar @cn, "\n";
    # print STDERR "cn first item size: ", scalar @{ $cn[0] }, "\n";  # returns 72 ?!
    # print STDERR "cn first first item: ", $cn[0][0], "\n";
    for(my $i = 0; $i < scalar @{ $cn[0] }; $i++) {
        print STDERR $cn[0][$i], "\n";
    }
    print STDERR "------ \n";

    # create confusion network (CN) containing transliterated words that are in the Arabic vocabulary, otherwise the Arabizi word itself
    # vocab = models/arabic-dict
    my @cn_lm = ();
    for(my $i=0; $i<@tokens; $i++) {
        for(my $j=0; $j<@{ $cn[$i] }; $j++) {
            my($msa_token, $derivations) = split(/\t/,$cn[$i][$j]);
            if(exists($vocab{$msa_token})) {
                push(@{ $cn_lm[$i] }, $msa_token);                
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
    if($use_lm) {
        my $viterbi_string=&score_lm_paths(\@cn_lm,\@stack);
        print "$viterbi_string\n";
    }
    else {
        for(my $i=0; $i<@tokens; $i++) {
            my $arabizi_string=$tokens_orig[$i];
            $arabizi_string=~s/ +//g;
            print "$arabizi_string $arabizi_string 1";
            for(my $j=0; $j<@{ $cn[$i] }; $j++) {
                my($msa_token,$derivations)=split(/\t/,$cn[$i][$j]);
                if(exists($vocab{$msa_token})) {
                    print " $msa_token 1";
                }
            }
            print "\n";
        }
    }
}

sub arabizi_msa_candidates {
    my($arabizi_tokens_string, $arabizi_map, $cn, $msa_substrings) = @_;

    my @arabizi_tokens = split(/ +/,$arabizi_tokens_string);
    
    if(scalar(@arabizi_tokens)>$MAX_WORD_LENGTH) {
        print STDERR "long word: $arabizi_tokens_string\n";
        return 1;
    }
    
    #unshift(@arabizi_tokens, '_BOW_');
    #push(@arabizi_tokens, '_EOW_');
    
    # add "a" before word starting with "l" (could be article Al)
    if($arabizi_tokens[0] eq 'l') {
        unshift(@arabizi_tokens,'a');
    }

    my $length = @arabizi_tokens;

    # special treatment of "an" at the end of word
    if($arabizi_tokens[$length-2] eq 'a' && $arabizi_tokens[$length-1] eq 'n') {
        $arabizi_tokens[$length-1] = 'nEOW';
    }

    my %state_current_position = ();
    my %state_output = ();
    my @active_states = ();
    push(@active_states,0);
    my @completed_states = ();

    my $last_state_id = 0;
    $state_current_position{0} = 0;
    @{ $state_output{0} } = ();

    my %state_derivation = ();
    @{ $state_derivation{0} } = ();

    my $nbStep = 0;
    while(@active_states > 0) {
        #$nbStep++;
        #print STDERR "nbStep:$nbStep.. ";
        #if($nbStep%100==0) { print STDERR "nbStep:$nbStep.. "; }
        #print STDERR "nbActStates: ", scalar(@active_states), "\n";
        
        my $state_id = shift(@active_states);
        my $current_position = $state_current_position{$state_id};

        my $output_prefix = join('',@{ $state_output{$state_id} });

        # TMP DBG
        # for(my $right=$current_position; $right<$length && $right-$current_position<$match_length; $right++) {
        for(my $right=$current_position; $right < $length && $right - $current_position < $match_length; $right++) {

            my $match_string = join(' ', @arabizi_tokens[$current_position..$right]);
            print STDERR $match_string, "\n";
            if(exists($$arabizi_map{$match_string})) {
                print STDERR "MATCH!", "\n";
                foreach my $msa_string (sort (keys %{ $$arabizi_map{$match_string} })) {
                    my $string = $output_prefix . $msa_string;
                    print STDERR "MATCH LOOP: ", $string, "\n";
                    $string=~s/ +//g;
                    $string=~s/\_DROP\_//g;
                    #$string=~s/\_BOW\_//g;
                    #$string=~s/\_EOW\_//g;

                    if(1||exists($$msa_substrings{$string})) {
                        $last_state_id++;
                        $state_current_position{$last_state_id}=$right+1;

                        @{ $state_output{$last_state_id} }=@{ $state_output{$state_id} };
                        push(@{ $state_output{$last_state_id} },$msa_string);
                        @{ $state_derivation{$last_state_id} }=@{ $state_derivation{$state_id} };
                        push(@{ $state_derivation{$last_state_id} },"$match_string :: $msa_string");

                        if($right+1==$length) {
                            push(@completed_states,$last_state_id);
                        } else {
                            push(@active_states,$last_state_id);
                        }                       
                    }
                }
            }
        }
    }

    my %completed_strings;
    for(my $i=0; $i<@completed_states; $i++) {
        my $string=join(' ',@{ $state_output{$completed_states[$i]} });
        $string=~s/ +//g;
        $string=~s/\_DROP\_//g;
        my $derivation=join('|',@{ $state_derivation{$completed_states[$i]} });
        push( @{ $completed_strings{$string} },$derivation);
    }

    foreach my $string (keys %completed_strings) {
        my $derivations=join(' ||| ',@{ $completed_strings{$string} });
        push(@$cn,"$string\t$derivations");

        my $arabizi_string=join('',@arabizi_tokens);
        if($arabizi_string=~/^[0-9]+$/) {
            push(@$cn,"$arabizi_string\tNIL");
        }
    }

    return 1;
}


sub preprocess {
    my($string)=@_;

    $string=lc($string);

    # remove repeated sequences of the same character
    my $str_bck = $string;
    $string=~s/(.)\1{2,}/$1$1/g;
    #if($str_bck ne $string) {  print STDERR "STR: $str_bck \t => $string \n"; }
    
    $string=~s/ +/SEP/g;
    my @chars=split(//,$string);
    $string=join(' ',@chars);
    $string=~s/S E P/SEP/g;

    $string=~s/ SEP e l SEP / SEP e l /g;
    $string=~s/^e l SEP /e l /g;
    $string=~s/ e n n / e l n /g;

    return $string;
}


sub score_lm_paths {
    my($cn_lm,$stack)=@_;
    
    my $last_state_id=0;
    my %state_back;
    my %state_output;
    my %state_score;
    my %state_history;

    $state_output{0}='<s>';
    $state_score{0}=0;
    @{ $state_history{0} }=( '<s>' );
    $stack->[0][0]=0;

    for(my $i=0; $i<@$cn_lm; $i++) {
        &prune_stack(\@{ $stack->[$i] },\%state_score,$stack_limit);
        for(my $j=0; $j<@{ $stack->[$i] }; $j++) {
#            print STDERR "IN stack->[$i][$j]\n";

            for(my $k=0; $k<@{ $cn_lm->[$i] }; $k++) {
                my @words_right=( $cn_lm->[$i][$k] );
                my $lm_prob=&lm_cost_between(\@{ $state_history{$stack->[$i][$j]} },\@words_right,$src_language_index,\%parameters,\%features,\%feature_name2id,0,\%dummy_hash,\@lm_srilm_ids,0);
                my $left=join(' ',@{ $state_history{$stack->[$i][$j]} });
                my $right=join(' ',@words_right);
#                print STDERR "p($right\|$left)=$lm_prob\n";
                $last_state_id++;
                @{ $state_history{$last_state_id} }=@{ $state_history{$stack->[$i][$j]} };
                push(@{ $state_history{$last_state_id} },$cn_lm->[$i][$k]);
                while(@{ $state_history{$last_state_id} }>$lm_order-1) {
                    shift(@{ $state_history{$last_state_id} });
                }
                $state_score{$last_state_id}=$state_score{$stack->[$i][$j]}+$lm_prob;
                $state_output{$last_state_id}=$cn_lm->[$i][$k];
                $state_back{$last_state_id}=$stack->[$i][$j];
                push(@{ $stack->[$i+1] },$last_state_id);
            }
        }

    }

    my $string=&get_viterbi($stack,\%state_score,\%state_back,\%state_output);
    return $string;
}

sub prune_stack {
    my($stack,$state_score,$stack_limit)=@_;

    my @sorted_states=(sort {-1*($$state_score{$a}<=>$$state_score{$b})} @$stack);
    undef @$stack;
    for(my $i=0; $i<$stack_limit && $i<@sorted_states; $i++) {
        push(@$stack,$sorted_states[$i]);
    }
}

sub get_viterbi {
    my($stack,$state_score,$state_back,$state_output)=@_;

    my $last_index=@$stack-1;
    my $max_final_arg;
    my $max_final_score;
    for(my $i=0; $i<@{ $stack->[$last_index] }; $i++) {
        if(!defined($max_final_score) || $$state_score{$stack->[$last_index][$i]}>$max_final_score) {
            $max_final_score=$$state_score{$stack->[$last_index][$i]};
            $max_final_arg=$stack->[$last_index][$i];
        }
    }

    my $current_state=$max_final_arg;
    my @max_derivation_yield;
    while(defined($$state_back{$current_state})) {
        $current_state=$$state_back{$current_state};
        unshift(@max_derivation_yield,$$state_output{$current_state});
    }
    #get rid off '<s>':
    shift(@max_derivation_yield);
    return join(' ',@max_derivation_yield);

}

