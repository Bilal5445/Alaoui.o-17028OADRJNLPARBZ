# The following paths have to be specified:
TEST=example/small-example # Set this to the filename to transliterate (the input to the pipeline will be $TEST.arabizi)
BASEDIR=/path/to/directory/where/software/lives
ARABIC_LM=/path/to/3gram/arabic/lm
DISAMBIG=/path/to/srilm/disambig
WPAIRS_DATA_FILE_ARABIZI=/path/to/arabizi/side/of/bitext # (e.g. LDC2013E125)
WPAIRS_DATA_FILE_ARABIC=/path/to/arabic/side/of/bitext # (e.g. LDC2013E125)
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
ARABIC_DICT=$BASEDIR/models/arabic-dict
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
    cat $TEST.arabizi | perl $TOKENIZE_EN - - | perl $LOWERCASE > $TEST.arabizi.ENTOK.lc

    echo "# extract dictionary of Arabizi test"
    cat $TEST.arabizi.ENTOK.lc | perl $TRAINDICT  > $TEST.arabizi.ENTOK.lc.dict

    echo "# get possible Arabizi->Arabic mappings"
    ( perl $TRANSCM --use-lm=no $ARABIC_DICT < $TEST.arabizi.ENTOK.lc.dict > $TEST.lc.az-ar.lex ) >& $TEST.lc.az-ar.lex.log
fi

if [ $ADD_WORD_PAIRS == 1 ]; then
    echo "# extract word transliteration pairs from Arabizi-Arabic corpus (tritext)"
    ( perl $EXTRACTWPAIRS \
        --arabizi=$WPAIRS_DATA_AZ \
        --arabic=$WPAIRS_DATA_AR \
        --map=$TEST.lc.az-ar.lex > $TEST.lc.az-ar.lex$WSUFF ) \
        >& $TEST.lc.az-ar.lex$WSUFF.log
fi

if [ 1 == 1 ]; then
    echo "# call SRILM disambig"
    $DISAMBIG -keep-unk \
        -map $MAP $TEST.lc.az-ar.lex$WSUFF -text $TEST.arabizi.ENTOK.lc \
        -lm $ARABIC_LM -order $LMORDER \
        | sed -r 's/^<s> //;s/ <\/s>$//' \
    > $TEST.arabizi.ENTOK.lc.disambig$WSUFF

    echo "# post-processing for special characters, smileys etc."
    $POSTPROCESS < $TEST.arabizi.ENTOK.lc.disambig$WSUFF > $TEST.arabizi.ENTOK.lc.disambig$WSUFF.pp
fi

echo "The final transliterated file is here:"

if [ $ADD_WORD_PAIRS == 1 ]; then
    cp $TEST.arabizi.ENTOK.lc.disambig$WSUFF.pp $TEST.charWordTransl
    echo $TEST.charWordTransl
else
    cp $TEST.arabizi.ENTOK.lc.disambig$WSUFF.pp $TEST.charTransl
    echo $TEST.charTransl
fi