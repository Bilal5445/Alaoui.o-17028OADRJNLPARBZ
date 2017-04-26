# The following paths have to be specified:
TEST=mad # Set this to the filename to transliterate (the input to the pipeline will be $TEST.arabizi)
BASEDIR=.

# scripts and binaries
TOKENIZE_EN=$BASEDIR/scripts/tokenizeE.pl
LOWERCASE=$BASEDIR/scripts/lowercase.pl
TRAINDICT=$BASEDIR/scripts/create-dictionary.pl
TRANSCM=$BASEDIR/scripts/arabizi2msa.pl

# models and data
ARABIC_DICT=$BASEDIR/models/arabic-dict

######## PIPELINE STARTS HERE ############

if [ 1 == 1 ]; then
    echo "# 1 tokenize and lowercase the Arabizi file => 1.$TEST.arabizi.ENTOK.lc.txt" 
    cat 0.$TEST.arabizi.txt | perl $TOKENIZE_EN - - | perl $LOWERCASE > 1.$TEST.arabizi.ENTOK.lc.txt

    echo "# 2 extract dictionary of Arabizi test => 2.$TEST.arabizi.ENTOK.lc.dict.txt"
    cat 1.$TEST.arabizi.ENTOK.lc.txt | perl $TRAINDICT  > 2.$TEST.arabizi.ENTOK.lc.dict.txt

    echo "# 3 get possible Arabizi->Arabic mappings => 3.$TEST.lc.az-ar.lex.txt"
    # ( perl $TRANSCM --use-lm=no $ARABIC_DICT < 2.$TEST.arabizi.ENTOK.lc.dict.txt > 3.$TEST.lc.az-ar.lex.txt ) # >& 4.$TEST.lc.az-ar.lex.log.txt
    # perl $TRANSCM --use-lm=no $ARABIC_DICT < 2.$TEST.arabizi.ENTOK.lc.dict.txt
    ( perl $TRANSCM --use-lm=no $ARABIC_DICT < 2.$TEST.arabizi.ENTOK.lc.dict.txt > 4.$TEST.lc.az-ar.lex.txt )

fi