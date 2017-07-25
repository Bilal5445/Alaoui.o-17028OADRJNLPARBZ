#
BASEDIR=.

# scripts and binaries
TRANSCM=$BASEDIR/scripts/arabizi2msavariants.pl

# models and data
ARABIC_DICT=$BASEDIR/models/moroccan-arabic-dict

#
perl $TRANSCM --use-lm=no $ARABIC_DICT <<< motalat