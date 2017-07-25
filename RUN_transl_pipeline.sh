# The following paths have to be specified:
TEST=example/small-example # Set this to the filename to transliterate (the input to the pipeline will be $TEST.arabizi)
# TEST=example/test_01_tkharbiq
# TEST=example/ex_g
# TEST=example/ex_fbalstek
# TEST=example/ex_nchallah
# TEST=example/ex_bezzaf
# TEST=example/ex_cridi
BASEDIR=.
ARABIC_LM=lm/moroccan_arabic_corpus_01.lm
DISAMBIG=srilm-1.7.2/bin/cygwin64/disambig.exe
# WPAIRS_DATA_FILE_ARABIZI=/path/to/arabizi/side/of/bitext # (e.g. LDC2013E125)
WPAIRS_DATA_FILE_ARABIZI=arabizi-arabic-bitext/arabizi-arabic-bitext.arz
# WPAIRS_DATA_FILE_ARABIC=/path/to/arabic/side/of/bitext # (e.g. LDC2013E125)
WPAIRS_DATA_FILE_ARABIC=arabizi-arabic-bitext/arabizi-arabic-bitext.ar
#####

ADD_WORD_PAIRS=1   # Set this to 1 to add transliterated word pairs, otherwise 0
NB_CORES=1         # If processing a large file, increase this to parallelize tokenization step

# scripts and binaries
TOKENIZE_EN=$BASEDIR/scripts/tokenizeE.pl
LOWERCASE=$BASEDIR/scripts/lowercase.pl
EXTRACTWPAIRS=$BASEDIR/scripts/arabic-to-arabizi-alignment.pl
TRAINDICT=$BASEDIR/scripts/create-dictionary.pl
TRANSCM=$BASEDIR/scripts/arabizi2msa.pl
POSTPROCESS=$BASEDIR/scripts/arabizi-transliteration-postprocessing.pl

# models and data
# ARABIC_DICT=$BASEDIR/models/arabic-dict
ARABIC_DICT=$BASEDIR/models/moroccan-arabic-dict
LMORDER=3

WSUFF=""
WPAIRS_DATA_AZ=""
WPAIRS_DATA_AR=""

if [ $ADD_WORD_PAIRS == 1 ]; then
    WSUFF="+word"
    
    cat $WPAIRS_DATA_FILE_ARABIZI| perl $TOKENIZE_EN - - | perl $LOWERCASE > $WPAIRS_DATA_FILE_ARABIZI.ENTOK.lc
    cat $WPAIRS_DATA_FILE_ARABIC | perl $TOKENIZE_EN - - | perl $LOWERCASE > $WPAIRS_DATA_FILE_ARABIC.ENTOK.lc
    
    WPAIRS_DATA_AZ=$WPAIRS_DATA_FILE_ARABIZI.ENTOK.lc
    WPAIRS_DATA_AR=$WPAIRS_DATA_FILE_ARABIC.ENTOK.lc
fi

######### PIPELINE STARTS HERE ############

if [ 1 == 1 ]; then
    echo "# tokenize and lowercase the Arabizi file" 
    cat $TEST.arabizi | perl $TOKENIZE_EN - - | perl $LOWERCASE > $TEST.1.arabizi.ENTOK.lc

    echo "# extract dictionary of Arabizi test"
    cat $TEST.1.arabizi.ENTOK.lc | perl $TRAINDICT > $TEST.2.arabizi.ENTOK.lc.dict

    echo "# get possible Arabizi->Arabic mappings"
    ( perl $TRANSCM --use-lm=no $ARABIC_DICT < $TEST.2.arabizi.ENTOK.lc.dict > $TEST.3.lc.az-ar.lex ) >& $TEST.4.lc.az-ar.lex.log
fi

if [ $ADD_WORD_PAIRS == 1 ]; then
    echo "# extract word transliteration pairs from Arabizi-Arabic corpus (tritext)"
    ( perl $EXTRACTWPAIRS \
        --arabizi=$WPAIRS_DATA_AZ \
        --arabic=$WPAIRS_DATA_AR \
        --map=$TEST.3.lc.az-ar.lex > $TEST.3.lc.az-ar.lex$WSUFF ) \
        >& $TEST.4.lc.az-ar.lex$WSUFF.log
fi

if [ 1 == 1 ]; then

    # check if 0.999 in $TEST.3.lc.az-ar.lex$WSUFF
    if grep -q "0.99" $TEST.3.lc.az-ar.lex$WSUFF; then
        echo "0.999 using no lm"
        #
        echo "# call SRILM disambig"
        echo "$DISAMBIG -keep-unk -map $MAP $TEST.3.lc.az-ar.lex$WSUFF -text $TEST.1.arabizi.ENTOK.lc | sed -r 's/^<s> //;s/ <\/s>$//' > $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF"
        $DISAMBIG -keep-unk \
            -map $MAP $TEST.3.lc.az-ar.lex$WSUFF -text $TEST.1.arabizi.ENTOK.lc \
            | sed -r 's/^<s> //;s/ <\/s>$//' \
        > $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF
    else
        echo "no 0.999 using lm"
        #
        echo "# call SRILM disambig"
        echo "$DISAMBIG -keep-unk -map $MAP $TEST.3.lc.az-ar.lex$WSUFF -text $TEST.1.arabizi.ENTOK.lc -lm $ARABIC_LM -order $LMORDER | sed -r 's/^<s> //;s/ <\/s>$//' > $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF"
        $DISAMBIG -keep-unk \
            -map $MAP $TEST.3.lc.az-ar.lex$WSUFF -text $TEST.1.arabizi.ENTOK.lc \
            -lm $ARABIC_LM -order $LMORDER \
            | sed -r 's/^<s> //;s/ <\/s>$//' \
        > $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF
    fi

    echo "# post-processing for special characters, smileys etc."
    $POSTPROCESS < $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF > $TEST.6.arabizi.ENTOK.lc.disambig$WSUFF.pp
fi

echo "The final transliterated file is here:"

if [ $ADD_WORD_PAIRS == 1 ]; then
    cp $TEST.6.arabizi.ENTOK.lc.disambig$WSUFF.pp $TEST.7.charWordTransl
    echo $TEST.7.charWordTransl
else
    cp $TEST.6.arabizi.ENTOK.lc.disambig$WSUFF.pp $TEST.7.charTransl
    echo $TEST.7.charTransl
fi