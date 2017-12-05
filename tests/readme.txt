- srilm-1.7.2/bin/cygwin64/ngram-count -text corpus/corpus_en_01.txt -order 3 -lm lm/corpus_en_01.lm
- srilm-1.7.2/bin/cygwin64/disambig -keep-unk -map $MAP test_01.lex.txt -text test_01.ENTOK.lc.txt -lm corpus/corpus_en_01.lm -order 3
- disambig -nbest N : gives the n best result and not only one
srilm-1.7.2/bin/cygwin64/disambig.exe -keep-unk -map  example/small-example.3.lc.az-ar.lex+word -text example/small-example.1.arabizi.ENTOK.lc -lm lm/moroccan_arabic_corpus_01.lm -order 3 -nbest 3 -mapw 100
srilm-1.7.2/bin/cygwin64/disambig.exe -keep-unk -map  example/small-example.3.lc.az-ar.lex -text example/small-example.1.arabizi.ENTOK.lc -lm lm/moroccan_arabic_corpus_01.lm -order 3 -nbest 10

// generate a language model (LM)
- srilm-1.7.2/bin/cygwin64/ngram-count -text corpus/170328_clean_numbers_and_non-arabic_words_morocco_corpus.txt -order 3 -lm lm/moroccan_arabic_corpus_01.lm
- srilm-1.7.2/bin/cygwin64/ngram-count -text corpus/170426_extended_dict.txt -order 3 -lm lm/moroccan_arabic_corpus_01.lm
- srilm-1.7.2/bin/cygwin64/ngram-count -text corpus/170426_extended_dict.txt -order 3 -lm lm/moroccan_arabic_corpus_01.lm -write-binary-lm

// generate a new arabic-dict (of words) from corpus (of sentences) each time we add new sentences to the corpus
- cat corpus/170426_extended_dict.txt | perl scripts/create-dictionary.pl > models/moroccan-arabic-dict

// info : dict & lm are not committed to versioning (because file too big: +7Meg & +49Meg). Do not forget to regenerate them with above commands if new pull to a new dev machine

// find variants : generated into example out.variants.txt
./RUN_transl_transcm.sh motolat