#!/bin/bash

# The following paths have to be specified:
TEST=example/small-example # Set this to the filename to transliterate (the input to the pipeline will be $TEST.arabizi)
# ability to pass the file from arg
if [ $# != 0 ]; then
    TEST=$1
fi

BASEDIR=.
ARABIC_LM=lm/moroccan_arabic_corpus_01.lm
DISAMBIG=srilm-1.7.2/bin/cygwin64/disambig.exe
WPAIRS_DATA_FILE_ARABIZI=arabizi-arabic-bitext/arabizi-arabic-bitext.arz
WPAIRS_DATA_FILE_ARABIC=arabizi-arabic-bitext/arabizi-arabic-bitext.ar

# NB_CORES=1         # If processing a large file, increase this to parallelize tokenization step
NB_CORES=2

# scripts and binaries
TOKENIZE_EN=$BASEDIR/scripts/tokenizeE.pl
LOWERCASE=$BASEDIR/scripts/lowercase.pl
EXTRACTWPAIRS=$BASEDIR/scripts/arabic-to-arabizi-alignment.pl
TRAINDICT=$BASEDIR/scripts/create-dictionary.pl
TRANSCM=$BASEDIR/scripts/arabizi2msa.pl
POSTPROCESS=$BASEDIR/scripts/arabizi-transliteration-postprocessing.pl

# models and data
ARABIC_DICT=$BASEDIR/models/moroccan-arabic-dict
LMORDER=3

WSUFF=""
WPAIRS_DATA_AZ=""
WPAIRS_DATA_AR=""

timestamp() {
  #date +"%s"
  date +%H:%M:%S:%3N
}

######### PIPELINE STARTS HERE ############

# Phase I : tokenize, lowercase, get mapping variants (and exlude variants not in dic)
if [ 1 == 1 ]; then
    timestamp 
    echo "# tokenize and lowercase the Arabizi file" 
    cat $TEST.arabizi | perl $TOKENIZE_EN - - | perl $LOWERCASE > $TEST.1.arabizi.ENTOK.lc

    timestamp
    echo "# extract dictionary of Arabizi test"
    cat $TEST.1.arabizi.ENTOK.lc | perl $TRAINDICT > $TEST.2.arabizi.ENTOK.lc.dict

    timestamp
    echo "# get possible Arabizi->Arabic mappings"
    ( perl $TRANSCM --use-lm=no $ARABIC_DICT < $TEST.2.arabizi.ENTOK.lc.dict > $TEST.3.lc.az-ar.lex ) >& $TEST.4.lc.az-ar.lex.log
fi

# Phase II : disambig
if [ 1 == 1 ]; then
    timestamp
    echo "# call SRILM disambig with LM"
    echo "$DISAMBIG -keep-unk -map $MAP $TEST.3.lc.az-ar.lex$WSUFF -text $TEST.1.arabizi.ENTOK.lc -lm $ARABIC_LM -order $LMORDER | sed -r 's/^<s> //;s/ <\/s>$//' > $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF"
    $DISAMBIG -keep-unk \
        -map $MAP $TEST.3.lc.az-ar.lex$WSUFF -text $TEST.1.arabizi.ENTOK.lc \
        -lm $ARABIC_LM -order $LMORDER \
        | sed -r 's/^<s> //;s/ <\/s>$//' \
    > $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF

    timestamp
    echo "# post-processing for special characters, smileys etc."
    $POSTPROCESS < $TEST.5.arabizi.ENTOK.lc.disambig$WSUFF > $TEST.6.arabizi.ENTOK.lc.disambig$WSUFF.pp
fi

timestamp
echo "The final transliterated file is here:"
cp $TEST.6.arabizi.ENTOK.lc.disambig$WSUFF.pp $TEST.7.charTransl
echo $TEST.7.charTransl
