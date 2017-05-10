srilm-1.7.2/bin/cygwin64/ngram-count -text corpus/corpus_en_01.txt -order 3 -lm lm/corpus_en_01.lm
srilm-1.7.2/bin/cygwin64/disambig -keep-unk -map $MAP test_01.lex.txt -text test_01.ENTOK.lc.txt -lm corpus/corpus_en_01.lm -order 3
srilm-1.7.2/bin/cygwin64/ngram-count -text corpus/170328_clean_numbers_and_non-arabic_words_morocco_corpus.txt -order 3 -lm lm/moroccan_arabic_corpus_01.lm

// generate a new (words) arabic-dict from (sentences) corpus each we add new sentences to the corpus
cat corpus/170426_extended_dict.txt | perl scripts/create-dictionary.pl > models/moroccan-arabic-dict