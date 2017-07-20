#
BASEDIR=.

# scripts and binaries
TRANSCM=$BASEDIR/scripts/arabizi2msa.pl

# models and data
ARABIC_DICT=$BASEDIR/models/moroccan-arabic-dict

#
perl $TRANSCM --use-lm=no $ARABIC_DICT <<< yan3al