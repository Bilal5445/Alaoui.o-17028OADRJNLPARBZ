#! /usr/bin/perl

use strict;

use Data::Dumper;

my $MAX_WORD_LENGTH = 17;
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
    # $line = "n _VOW_ d";
    # print STDERR "$line\n"; die;

    #
    my %msa_substrings = ();
    my @tokens = split(/ SEP /o, $line);

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
    } 

    # create confusion network (CN) containing transliterated words that are in the Arabic vocabulary, otherwise the Arabizi word itself
    # vocab = models/arabic-dict
    my @cn_lm = ();
    for (my $i = 0; $i < @tokens; $i++) {
        for (my $j = 0; $j < @{ $cn[$i] }; $j++) {
            my($msa_token, $derivations) = split(/\t/, $cn[$i][$j]);
            print STDERR $msa_token, "\n";  # this prints out the variants
        }
    }
}

sub arabizi_msa_candidates {
    my($arabizi_tokens_string, $arabizi_map, $cn, $msa_substrings) = @_;

    my @arabizi_tokens = split(/ +/, $arabizi_tokens_string);
    
    # ignore if numeric (ex: "28") ie : containing numeral or comma or period
    if ( $arabizi_tokens_string =~ /^[0-9, .]+$/ ) {
        return 1;
    }

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
    # MC092417 Comment this code and let ptable & lm decide
    #if($arabizi_tokens[$length-2] eq 'a' && $arabizi_tokens[$length-1] eq 'n') {
    #    $arabizi_tokens[$length-1] = 'nEOW';
    #}

    # empty hashes and arrays to work with
    my %state_current_position = (); $state_current_position{0} = 0;
    my %state_output = (); @{ $state_output{0} } = ();
    my @active_states = (); push(@active_states, 0);
    my @completed_states = ();
    my %state_derivation = (); @{ $state_derivation{0} } = ();

    # vars
    my $last_state_id = 0;
    my $nbStep = 0;

    # while array active_states not empty
    while (@active_states > 0) {
        
        my $state_id = shift(@active_states);
        my $current_position = $state_current_position{$state_id};
        my $output_prefix = join('', @{ $state_output{$state_id} });

        #
        # my $prev_match_string;
        for (my $right = $current_position; 
            $right < $length && $right - $current_position < $match_length; 
            $right++) {

            my $match_string = join(' ', @arabizi_tokens[$current_position..$right]);
            # print STDERR "arr : " . join(", ", @arabizi_tokens) . "\n";
            # my $prev_match_string = join(' ', @arabizi_tokens[$current_position..($right-1)]);
            my $prev_match_char;
            if ($current_position>0) {
                $prev_match_char = join(' ', @arabizi_tokens[$current_position-1]);
            }
            # print STDERR "match_string : " . $match_string . "\n";
            # print STDERR "prev_match_string : " . $prev_match_string . "\n";
            # print STDERR "prev_match_char : " . $prev_match_char . "\n";
            # print STDERR "current_position : " . $current_position . "\n";
            if (exists($$arabizi_map{$match_string})) {
                foreach my $msa_string (sort (keys %{ $$arabizi_map{$match_string} })) {
                    my $string = $output_prefix . $msa_string;
                    $string =~ s/ +//g;         # remove spaces
                    $string =~ s/\_DROP\_//g;   # remove any _DROP_
                    #$string=~s/\_BOW\_//g;
                    #$string=~s/\_EOW\_//g;

                    $last_state_id++;
                    $state_current_position{$last_state_id} = $right + 1;

                    # insert the arabic letter msa_string into the array in the hash state_output
                    # MC200717 but only if the previous char is compatible
                    # MC250717 also for 'o', should not be 'haa' only if final
                    my $currArabicChar = $msa_string;
                    my @tmpArray = @{ $state_output{$state_id} };
                    my $prevArabicChar = $tmpArray[-1];
                    if (&IsCompatibleWithPrevious($right, $length, $match_string, $prev_match_char, $currArabicChar, $prevArabicChar)) {
                        
                        @{ $state_output{$last_state_id} } = @{ $state_output{$state_id} };
                        push(@{ $state_output{$last_state_id} }, $msa_string);
                        # print Dumper(\%state_output); return 1;

                        #
                        @{ $state_derivation{$last_state_id} } = @{ $state_derivation{$state_id} };
                        push(@{ $state_derivation{$last_state_id} }, "$match_string :: $msa_string");
                        # print Dumper(\%state_derivation); # return 1;

                        if ($right + 1 == $length) {
                            push(@completed_states, $last_state_id);
                        } else {
                            push(@active_states, $last_state_id);
                        }
                    }
                }
            }
            # MC250118 so we can use previous arabizi letter for our comparisons
            # $prev_match_string = $match_string;
        }
    }

    #
    my %completed_strings;
    for(my $i = 0; $i < @completed_states; $i++) {
        my $string = join(' ', @{ $state_output{$completed_states[$i]} });
        $string =~ s/ +//g;         # remove spaces
        $string =~ s/\_DROP\_//g;   # remove any _DROP_
        my $derivation = join('|',@{ $state_derivation{$completed_states[$i]} });
        push( @{ $completed_strings{$string} }, $derivation);
    }
    
    foreach my $string (keys %completed_strings) {
        my $derivations = join(' ||| ', @{ $completed_strings{$string} });
        push(@$cn, "$string\t$derivations"); # string contains recomposed arabic string (eg: يانعآل one of the possible variations for 'yan3al')
        
        my $arabizi_string = join('', @arabizi_tokens);
        if($arabizi_string =~ /^[0-9]+$/) {
            push(@$cn,"$arabizi_string\tNIL");
        }
    }

    return 1;
}

sub IsCompatibleWithPrevious {
    my($right, $length, $match_string, $prev_match_char, $currArabicChar, $prevArabicChar) = @_;

    # MC280917 medial 'i' cannot be 'waw'
    # MC280917 final 'i' cannot be 'waw'
    # MC280917 beginning 'i' can be 'waw' : ex 'ikabri lablado' => 'wa kabri lablado'
    # MC280917 isolated 'i' can be 'waw' : ex : 'la hokoma i sarha'
    if ($match_string eq 'i' and $currArabicChar eq 'و' and $right > 0) {
        return 0;
    }

    # MC250118 'ou' cannot be 'yaa' : means cannot have 'o' dropped and 'u' mapped to 'yaa'
    # eg : '3endou' cannot becomes 'عندي'
    # print STDERR "1 match_string : $match_string ";
    # print STDERR "2 prev_match_char : $prev_match_char ";
    # print STDERR "3 currArabicChar : $currArabicChar\n";
    if ($match_string eq 'u' and $prev_match_char eq 'o' and $currArabicChar eq 'ي') {
        # print STDERR "match\n";
        return 0;
    }

    # MC280917 isolated 'i' cannot be 'alef' : ex : 'la hokoma i sarha'
    #if ($match_string eq 'i' and $currArabicChar eq 'ا' and $length = 1) {
    #    return 0;
    #}
    #if ($match_string eq 'i' and $currArabicChar eq 'إ' and $length = 1) {
    #    print STDERR "right : ", $right, "\n";
    #    print STDERR "length : ", $length, "\n";
    #    print STDERR "match_string : ", $match_string, "\n";
    #    print STDERR "currArabicChar : ", $currArabicChar, "\n";
    #    print STDERR "prevArabicChar : ", $prevArabicChar, "\n";
    #    return 0;
    #}

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

    # MC301117 'a' can be '_DROP_' only if not final
    if ($match_string eq 'a' and $currArabicChar eq '_DROP_' and $right == ($length -1) ) {
        # print STDERR "for letter $match_string, the pos is $right : $currArabicChar : $prevArabicChar", "\n";
        return 0;
    }
    # MC301117 'i' can be '_DROP_' only if not final
    if ($match_string eq 'i' and $currArabicChar eq '_DROP_' and $right == ($length -1) ) {
        # print STDERR "for letter $match_string, the pos is $right : $currArabicChar : $prevArabicChar", "\n";
        return 0;
    }
    # MC301117 'o' can be '_DROP_' only if not final
    if ($match_string eq 'o' and $currArabicChar eq '_DROP_' and $right == ($length -1) ) {
        # print STDERR "for letter $match_string, the pos is $right : $currArabicChar : $prevArabicChar", "\n";
        return 0;
    }

    # MC260817 'i' (or 'e') can be 'alef' only if initial
    # MC290817 'i' (or 'e') can also be 'alef' if not initial but after 'alef-lam'
    # MC171117 also the case where we start with 'f' ex : 'felkhadma'
    if ($match_string eq 'i' and $currArabicChar eq 'ا' and $right > 0 and $prevArabicChar ne 'ل' and $prevArabicChar ne 'ف') {
        return 0;
    }
    if ($match_string eq 'e' and $currArabicChar eq 'ا' and $right > 0 and $prevArabicChar ne 'ل' and $prevArabicChar ne 'ف') {
        return 0;
    }
    if ($match_string eq 'i' and $currArabicChar eq 'إ' and $right > 0 and $prevArabicChar ne 'ل' and $prevArabicChar ne 'ف') {
        return 0;
    }
    if ($match_string eq 'e' and $currArabicChar eq 'إ' and $right > 0 and $prevArabicChar ne 'ل' and $prevArabicChar ne 'ف') {
        return 0;
    }

    # remove impossible combo
    if ($prevArabicChar eq 'ى') {
        return 0;
    } elsif ($prevArabicChar eq 'ة') {
        return 0;
    } elsif ($prevArabicChar eq 'ت' and $currArabicChar eq 'ت') {
        return 0;
    } elsif ($prevArabicChar eq 'ث' and $currArabicChar eq 'ث') {
        return 0;
    } elsif ($prevArabicChar eq 'ط' and $currArabicChar eq 'ط') {
        return 0;
    } elsif ($prevArabicChar eq 'ط' and $currArabicChar eq 'ص') {
        return 0;
    } elsif ($prevArabicChar eq 'س' and $currArabicChar eq 'س') {
        return 0;
    } elsif ($prevArabicChar eq 'ص' and $currArabicChar eq 'ص') {
        return 0;
    } elsif ($prevArabicChar eq 'ص' and $currArabicChar eq 'س') {
        return 0;
    } elsif ($prevArabicChar eq 'ص' and $currArabicChar eq 'ش') {
        return 0;
    } elsif ($prevArabicChar eq 'س' and $currArabicChar eq 'ص') {
        return 0;
    } elsif ($prevArabicChar eq 'ش' and $currArabicChar eq 'ص') {
        return 0;
    } elsif ($prevArabicChar eq 'ا' and $currArabicChar eq 'ا') {
        return 0;
    } elsif ($prevArabicChar eq '_DROP_' and $currArabicChar eq '_DROP_') {
        return 0;
    } elsif ($prevArabicChar eq 'ي' and $currArabicChar eq 'ي') {
        return 0;
    } elsif ($prevArabicChar eq 'إ' and $currArabicChar eq 'إ') {
        return 0;
    } elsif ($prevArabicChar eq 'إ' and $currArabicChar eq 'ا') {
        return 0;
    } elsif ($prevArabicChar eq 'ئ' and $currArabicChar eq 'و') {
        return 0;
    } elsif ($prevArabicChar eq 'و' and $currArabicChar eq 'و') {
        return 0;
    } elsif ($prevArabicChar eq 'ج' and $currArabicChar eq 'ج') {
        return 0;
    } elsif ($currArabicChar eq 'إ' and $prevArabicChar ne '') {
        return 0;       
    } else {         
        return 1;
    }
}

sub preprocess {
    my($string)=@_;

    # lowercase
    $string = lc($string);

    # remove repeated sequences of the same character
    my $str_bck = $string;
    $string=~s/(.)\1{2,}/$1$1/g;
    #if($str_bck ne $string) {  print STDERR "STR: $str_bck \t => $string \n"; }
    
    # replace 'é' by 'e' and other accented letter
    $string =~ s/é/e/g;

    # pass through SEP (spaces)
    $string =~ s/ +/SEP/g;
    my @chars = split(//, $string);
    $string = join(' ', @chars);
    $string=~s/S E P/SEP/g;

    $string=~s/ SEP e l SEP / SEP e l /g;
    $string=~s/^e l SEP /e l /g;
    # $string=~s/ e n n / e l n /g;

    # pass through _VOW_ (vowels)
    # print STDERR  "string : $string\n"; die;
    $string=~s/_ v o w _/_VOW_/g;
    # $string=~s/\_/\\\_/g;
    # $string=~s/\_/\_/g;
    # $string=~s/([^ \_])(\_+)/$1 $2/g;
    # $string=~s/([^ \_])(\_{2,})/$1 $2/g;
    # $string=~s/(\_{2,})([^ \_])/$1 $2/g;
    # $string=~s/\_{3,}/\_\_/g;
    # print STDERR  "string : $string\n"; die;

    return $string;
}
