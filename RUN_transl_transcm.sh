#
BASEDIR=.

# scripts and binaries
TRANSCM=$BASEDIR/scripts/arabizi2msavariants.pl

# models and data
ARABIC_DICT=$BASEDIR/models/moroccan-arabic-dict

#
cat arabiziword | perl $TRANSCM >& example/out.variants.txt
# perl $TRANSCM --use-lm=no $ARABIC_DICT <<< layla
# perl $TRANSCM --use-lm=no $ARABIC_DICT <<< "Sir ya haz9ane lah yan3al l9ahba mok nta o yah"