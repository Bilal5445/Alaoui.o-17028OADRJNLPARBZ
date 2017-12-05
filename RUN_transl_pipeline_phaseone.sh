# The following paths have to be specified:
TEST=example/small-example # Set this to the filename to transliterate (the input to the pipeline will be $TEST.arabizi)
BASEDIR=.

# scripts and binaries
TOKENIZE_EN=$BASEDIR/scripts/tokenizeE.pl
LOWERCASE=$BASEDIR/scripts/lowercase.pl
TRAINDICT=$BASEDIR/scripts/create-dictionary.pl
TRANSCM=$BASEDIR/scripts/arabizi2msa.pl

# models and data
ARABIC_DICT=$BASEDIR/models/moroccan-arabic-dict

timestamp() {
  date +%H:%M:%S:%3N
}

# Phase I : tokenize, lowercase, get mapping variants (and exlude variants not in dic)
timestamp 
if [ 1 == 1 ]; then
    echo "# tokenize and lowercase the Arabizi file" 
    cat $TEST.arabizi | perl $TOKENIZE_EN - - | perl $LOWERCASE > $TEST.1.arabizi.ENTOK.lc

    timestamp
    echo "# extract dictionary of Arabizi test"
    cat $TEST.1.arabizi.ENTOK.lc | perl $TRAINDICT > $TEST.2.arabizi.ENTOK.lc.dict

    timestamp
    echo "# get possible Arabizi->Arabic mappings > $TEST.3.lc.az-ar.lex"
    ( perl $TRANSCM --use-lm=no $ARABIC_DICT < $TEST.2.arabizi.ENTOK.lc.dict > $TEST.3.lc.az-ar.lex ) >& $TEST.4.lc.az-ar.lex.log
fi
timestamp