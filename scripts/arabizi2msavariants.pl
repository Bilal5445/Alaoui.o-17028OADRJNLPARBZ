#! /usr/bin/perl

use strict;

my $MAX_WORD_LENGTH = 12;
my $match_length=2;

my $print_derivation=0;
my $pre_process=1;
my $stack_limit=10;
my $lm_order=3;

my $OISTERHOME=$ENV{'OISTERHOME'};

my $arabizi_pt_file='models/ptable'; # e.g. constructed from LDC2013E125

my %parameters;
my %features;
$parameters{'lm_cap'}=0;
$parameters{'lm_order'}=$lm_order;
$features{'lm_weight'}=1;
$features{0}=1;
my %feature_name2id;
$feature_name2id{'lm_weight'}=0;
 
my $src_language_index=0;

my %dummy_hash;

my %arabizi_map; # contains possible character replacements for each Arabizi character
open(F,"<$arabizi_pt_file")||die("can't open arabizi_pt_file file $arabizi_pt_file: $!\n");
while(defined(my $line=<F>)) {
    chomp($line);
    my($f,$e,@rest)=split(/ \|\|\| /o,$line);
    $arabizi_map{$f}{$e}=1;    
}
close(F);

my $nbl = 0;
while (defined(my $line=<STDIN>)) {
    $nbl++;
    if ($nbl % 50 == 0) { print STDERR "line $nbl..."; };
    # print STDERR "line $line \n";
    
    # remove ending \n and any whitespaces inside (space, cr, lf, ...) 
    chomp($line);
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;

    #
    my @tokens_orig = split(/ /o, $line);
    # separate letters : eg : yan3al => y a n 3 a l
    if($pre_process) {
        $line = &preprocess($line);
    }

    #
    my %msa_substrings = ();
    my @tokens = split(/ SEP /o, $line);
    # print STDERR "line: ", $line, "\n";
    # print STDERR "tokens: ", $tokens[0], "\n";

    #
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
    # for(my $i = 0; $i < scalar @{ $cn[0] }; $i++) {
    #    print STDERR $cn[0][$i], "\n";
    # }
    # print STDERR "------ \n";
    # at this point, we have all arabic variations possible (included the wierd ones : eg : taa marbouta in middle of word) for the entry arabizi word
    # TODO : drop the wierd variations
}

sub arabizi_msa_candidates {
    my($arabizi_tokens_string, $arabizi_map, $cn, $msa_substrings) = @_;

    my @arabizi_tokens = split(/ +/, $arabizi_tokens_string);
    
    # check length of word
    if (scalar(@arabizi_tokens) > $MAX_WORD_LENGTH) {
        print STDERR "long word: $arabizi_tokens_string\n";
        return 1;
    }
    
    # unshift(@arabizi_tokens, '_BOW_');
    # push(@arabizi_tokens, '_EOW_');
    
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

    my $last_state_id = 0;
    $state_current_position{0} = 0;
    @{ $state_output{0} } = ();

    my %state_derivation = ();
    @{ $state_derivation{0} } = ();

    my $nbStep = 0;
    while (@active_states > 0) {
        #$nbStep++;
        #print STDERR "nbStep:$nbStep.. ";
        #if($nbStep%100==0) { print STDERR "nbStep:$nbStep.. "; }
        #print STDERR "nbActStates: ", scalar(@active_states), "\n";
        
        my $state_id = shift(@active_states);
        my $current_position = $state_current_position{$state_id};

        my $output_prefix = join('', @{ $state_output{$state_id} });

        #
        for (my $right = $current_position; $right < $length && $right - $current_position < $match_length; $right++) {

            my $match_string = join(' ', @arabizi_tokens[$current_position..$right]);
            # print STDERR "string to match : ", $match_string, "\n";
            if (exists($$arabizi_map{$match_string})) {
                # print STDERR "------------ ('$match_string') \n";
                # print STDERR "MATCH! '$match_string' in ptable", "\n";
                # print STDERR $match_string;
                foreach my $msa_string (sort (keys %{ $$arabizi_map{$match_string} })) {
                    my $string = $output_prefix . $msa_string;
                    # print STDERR "msa string : $msa_string for $match_string ==> ";
                    # print STDERR "MATCH LOOP: ", $string, "\n";
                    $string =~ s/ +//g;         # remove spaces
                    $string =~ s/\_DROP\_//g;   # remove any _DROP_
                    #$string=~s/\_BOW\_//g;
                    #$string=~s/\_EOW\_//g;

                    # if (1 || exists($$msa_substrings{$string})) {
                        $last_state_id++;
                        $state_current_position{$last_state_id} = $right + 1;

                        # insert the arabic letter msa_string into the array in the hash state_output
                        # MC200717 but only if the previous char is compatible
                        # MC250717 also for 'o', should not be 'haa' only if final
                        my $currArabicChar = $msa_string;
                        my @tmpArray = @{ $state_output{$state_id} };
                        my $prevArabicChar = $tmpArray[-1];
                        if (&IsCompatibleWithPrevious($right, $length, $match_string, $currArabicChar, $prevArabicChar)) {
                            # print STDERR $currArabicChar, ".", $prevArabicChar, " = OK\n";
                            # print STDERR $currArabicChar, ".", $prevArabicChar, " = KO\n";
                        
                        @{ $state_output{$last_state_id} } = @{ $state_output{$state_id} };
                        push(@{ $state_output{$last_state_id} }, $msa_string);

                        #
                        @{ $state_derivation{$last_state_id} } = @{ $state_derivation{$state_id} };
                        push(@{ $state_derivation{$last_state_id} }, "$match_string :: $msa_string");

                        if ($right + 1 == $length) {
                            push(@completed_states, $last_state_id);
                        } else {
                            push(@active_states, $last_state_id);
                        }
                        }                       
                    # }
                }
            }
        }
    }

    # print STDERR "scalar state output $ : ", scalar($state_output), "\n";
    # print STDERR "scalar state output % : ", scalar(%state_output), "\n";
    # print STDERR "scalar state output % 2 : ", scalar %state_output, "\n";
    # print STDERR "scalar keys % state output : ", scalar keys %state_output, "\n";
    # print STDERR "scalar @ completed_states : ", scalar(@completed_states), "\n";

    # DBG : show content of the hash %state_output
=pod
    my $y = 0;
    foreach my $key (keys %state_output) {
        print STDERR $y, " : ";
        $y++;
        print STDERR $key, "\t";
        print STDERR scalar(@{ $state_output{$key} }), "\t";
        print STDERR join(".", @{ $state_output{$key} }),"\n";
    }
=cut

    #
    my %completed_strings;
    for(my $i = 0; $i < @completed_states; $i++) {
        my $string = join(' ', @{ $state_output{$completed_states[$i]} });
        # print STDERR $string, " => ";
        $string =~ s/ +//g;         # remove spaces
        $string =~ s/\_DROP\_//g;   # remove any _DROP_
        print STDERR $string, "\n";
        my $derivation = join('|',@{ $state_derivation{$completed_states[$i]} });
        # print STDERR $derivation, "\n";
        push( @{ $completed_strings{$string} }, $derivation);
    }
    
    foreach my $string (keys %completed_strings) {
        my $derivations = join(' ||| ', @{ $completed_strings{$string} });
        push(@$cn, "$string\t$derivations"); # string contains recomposed arabic string (eg: يانعآل one of the possible variations for 'yan3al')
        # print STDERR "$string\t$derivations", "\n";
        # print STDERR "$derivations", "\n";
        # print STDERR "$string", "\n";
        
        # print STDERR "-----------", "\n";
        my $arabizi_string = join('', @arabizi_tokens);
        # print STDERR "$arabizi_string", "\n";
        if($arabizi_string =~ /^[0-9]+$/) {
            push(@$cn,"$arabizi_string\tNIL");
        }
    }

    return 1;
}

sub IsCompatibleWithPrevious {
    my($right, $length, $match_string, $currArabicChar, $prevArabicChar) = @_;

    # MC250717 also for 'o', should not be 'haa' only if final
    if ($match_string eq 'o' and $currArabicChar eq 'ه' and $right < ($length -1) ) {
        # print STDERR "for letter $match_string, the pos is $right : $currArabicChar : $prevArabicChar", "\n";
        return 0;
    }
    # same for 'e' to 'haa'
    if ($match_string eq 'e' and $currArabicChar eq 'ه' and $right < ($length -1) ) {
        # print STDERR "for letter $match_string, the pos is $right : $currArabicChar : $prevArabicChar", "\n";
        return 0;
    }

    # remove impossible combo
    if ($prevArabicChar eq 'ى') {
        return 0;
    } elsif ($prevArabicChar eq 'ة') {
        return 0;
    } else {         
        return 1;
    }
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
