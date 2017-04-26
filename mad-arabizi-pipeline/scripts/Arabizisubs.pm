package Arabizisubs; # use package to declare a module

my $MAX_WORD_LENGTH = 12;

sub arabizi_msa_candidates {
    my($arabizi_tokens_string, $arabizi_map, $cn, $msa_substrings) = @_;

    # DBG
    # print STDOUT "arabizi_msa_candidates - start for : $arabizi_tokens_string\n";
    
    # Every word is splitted to an array of letters
    my @arabizi_tokens = split(/ +/, $arabizi_tokens_string);
    
    # my $scalar_arabizi_tokens = scalar(@arabizi_tokens);
    # print STDERR "scalar arabizi_token:  $scalar_arabizi_tokens\n";
    # print STDERR "MAX_WORD_LENGTH:  $MAX_WORD_LENGTH\n";
    if(scalar(@arabizi_tokens) > $MAX_WORD_LENGTH) {
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
    push(@active_states, 0);
    my @completed_states = ();

    my $last_state_id=0;
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
        
        my $state_id=shift(@active_states);
        my $current_position = $state_current_position{$state_id};

        my $output_prefix = join('', @{ $state_output{$state_id} });

        for(my $right = $current_position; $right < $length && $right-$current_position < $match_length; $right ++) {

            my $match_string = join(' ', @arabizi_tokens[$current_position..$right]);
            if(exists($$arabizi_map{$match_string})) {

                foreach my $msa_string (sort (keys %{ $$arabizi_map{$match_string} })) {
                    my $string = $output_prefix . $msa_string;
                    $string=~s/ +//g;
                    $string=~s/\_DROP\_//g;
                    #$string=~s/\_BOW\_//g;
                    #$string=~s/\_EOW\_//g;

                    if(1 || exists($$msa_substrings{$string})) {
                        $last_state_id ++;
                        $state_current_position{$last_state_id} = $right + 1;

                        @{ $state_output{$last_state_id} } = @{ $state_output{$state_id} };
                        push(@{ $state_output{$last_state_id} },$msa_string);
                        @{ $state_derivation{$last_state_id} } = @{ $state_derivation{$state_id} };
                        push(@{ $state_derivation{$last_state_id} },"$match_string :: $msa_string");

                        if($right + 1 == $length) {
                            push(@completed_states, $last_state_id);
                        } else {
                            push(@active_states, $last_state_id);
                        }                       
                    }
                }
            }
        }
    }

    my %completed_strings;
    for(my $i = 0; $i < @completed_states; $i ++) {
        my $string = join(' ', @{ $state_output{$completed_states[$i]} });
        $string =~ s/ +//g;
        $string =~ s/\_DROP\_//g;
        my $derivation = join('|', @{ $state_derivation{$completed_states[$i]} });
        push( @{ $completed_strings{$string} }, $derivation);
    }

    foreach my $string (keys %completed_strings) {
        my $derivations = join(' ||| ',@{ $completed_strings{$string} });
        push(@$cn, "$string\t$derivations");

        my $arabizi_string = join('', @arabizi_tokens);
        if($arabizi_string =~ /^[0-9]+$/) {
            push(@$cn, "$arabizi_string\tNIL");
        }
    }

    return 1;
}

sub preprocess {
    # print STDOUT "preprocess - start \n";

    my($string)=@_;

    $string=lc($string);

    # remove repeated sequences of the same character
    my $str_bck = $string;
    $string =~ s/(.)\1{2,}/$1$1/g;
    #if($str_bck ne $string) {  print STDERR "STR: $str_bck \t => $string \n"; }
    
    $string =~ s/ +/SEP/g;
    my @chars = split(//,$string);
    $string = join(' ',@chars);
    $string =~ s/S E P/SEP/g;

    $string =~ s/ SEP e l SEP / SEP e l /g;
    $string =~ s/^e l SEP /e l /g;
    $string =~ s/ e n n / e l n /g;

    return $string;
}

sub score_lm_paths {
    print STDOUT "score_lm_paths - start \n";

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

            for(my $k=0; $k<@{ $cn_lm->[$i] }; $k++) {
                my @words_right=( $cn_lm->[$i][$k] );
                my $lm_prob=&lm_cost_between(\@{ $state_history{$stack->[$i][$j]} },\@words_right,$src_language_index,\%parameters,\%features,\%feature_name2id,0,\%dummy_hash,\@lm_srilm_ids,0);
                my $left=join(' ',@{ $state_history{$stack->[$i][$j]} });
                my $right=join(' ',@words_right);
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
    print STDOUT "prune_stack - start \n";

    my($stack,$state_score,$stack_limit)=@_;

    my @sorted_states=(sort {-1*($$state_score{$a}<=>$$state_score{$b})} @$stack);
    undef @$stack;
    for(my $i=0; $i<$stack_limit && $i<@sorted_states; $i++) {
        push(@$stack,$sorted_states[$i]);
    }
}

sub get_viterbi {
    print STDOUT "get_viterbi - start \n";

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

1;