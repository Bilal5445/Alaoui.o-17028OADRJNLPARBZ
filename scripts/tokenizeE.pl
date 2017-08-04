#!/usr/bin/perl

# Latest updates:
#
# Changed the treatment of apostrophe contractions: commented out Estem_elision(), 
#   modified and moved Estem_contractions. Michael Subotin. Mar 13, 2005
# Copied Christof's code to deal with  with begin and end tags. Michael Subotin. Mar 5, 2005
# Uncommented &Estem_elision(); Michael Subotin. Feb 22, 2005
# Added apostrophe sub. Michael Subotin. Feb 24, 2005
#
# File      : tokenizer
# Author    : Okan Kolak, okan@cs.umd.edu
# Created   : June 4, 2000
# Modified  : July 15, 2004
# Desc      : Tokenizes English text files to be used by depgraph
# Note      : a modified (by Mona Diab and Okan Kolak) version of
#             tokenizeE.pl of EGYPT package is inserted into this code
#             with additional support for reading from files

if(scalar(@ARGV) != 2){
    die "\nUsage: $0 <infile> <outfile>\n\n<infile>: name of input file, or - to use STDIN\n\n<outfile>: name of output file, or - to use STDOUT\n\n";
}

#if ($ARGV[0] eq "-"){
#  open(INP, "cat|") or die "Cannot open STDIN\n";
#} else {
  open(INP, $ARGV[0]) or die "Cannot open input file $ARGV[0]\n";
binmode(INP, ":utf8");
#}

#if ($ARGV[1] eq "-"){
  open(OUT, ">$ARGV[1]") or die "Cannot create output file $ARGV[1]\n";
binmode(OUT, ":utf8");
#} else {
#  open(OUT, "|") or die "Cannot open STDOUT\n";
#}


###########################################################################
# This is a tokenizer for English. It was written as a single perl script #
#      by Yaser Al-Onaizan based on several scripts by Dan Melamed.       #
#  WS'99 STatistical Machine Translation Team.                            #
#  IN: Englsih text in STDIN                                              #
#  OUT: tokenized English text in STDOUT                                  #
###########################################################################

$ctrl_m=chr(13);

while(<INP>){
    chomp();

    # 5dh => 5 dh
    s/\b(\d+)dh\b/$1 dh/g;
    # 30min => 30 min
    s/\b(\d+)min\b/$1 minutes/g; # minutes instead of min because min is confusing
    # 5go => 5 go
    s/\b(\d+)go\b/$1 go/g;

    s/^([^ ])/ $1/;
    s/([^ ])$/$1 /;
#    s/\xe2\x80\x9c/\"/g;
#    s/\xe2\x80\x9d/\"/g;
    
    s/$ctrl_m/ /g;
#    s/^\s*//;
#    s/\s*$//;

    tr/ / /;  # remove character 160 - non breaking space
    tr/\t/ /; # Replace all tabs with space
    s/(http:\/\/[^ \)\(]*[^\.\,\: \(\)\[\]])/<url>$1<\/url>/g;
    s/(<[^>]+\@[^>]+>[^\.\,\: \(\)\[\]])/<url>$1<\/url>/g;
    s/([^ \(\)]+\@[^ \)\(]+\.[^ \)\(\,]+)/<url>$1<\/url>/g;
    s/([\s\(\[\:\;])(www\.[^ \)\(]+\.[^ \)\(]*[^\.\,\: \(\)\[\]])/$1<url>$2<\/url>/g;
    s/^(www\.[^ \)\(]+\.[^ \)\(]*[^\.\,\: \(\)\[\]])/<url>$1<\/url>/g;

    # use this to deal with urls in general?
    s/ (([A-Za-z0-9\-]+\s*\.)+?(com|edu|net|org|ac\.uk|org\.uk|co\.uk|ae|af|ar|at|au|az|be|bg|br|ca|ch|cl|cz|de|dk|eg|es|fi|fr|ge|gr|hk|hr|ie|il|in|ir|is|it|jo|jp|kg|kr|kw|kz|lk|lu|lv|mg|mn|mt|mx|my|nl|no|nz|ph|pk|qa|ro|ru|sa|se|sg|si|sk|sn|so|su|th|tj|tm|tn|tr|tw|ua|ug|uk|za)) /<url>$1<\/url>/g;


#    s/([^ \(\)\@]+\.com)/<url>$1<\/url>/g;

    #for image and file names:
    s/(<(?:DOCID|docid)>.*?<\/(?:DOCID|docid)>)/<url>$1<\/url>/g;
    s/([^ \)\(]+\.(?:gif|jpg|jpeg))/<url>$1<\/url>/g;
    s/(<\/?(?:doc|poster|headline|DOC|POSTER|HEADLINE)>)/<url>$1<\/url>/g;

#    &Estem_elision();

    &Edelimit_tokens();
    &apostrophe();
    &Estem_contractions();
    &Emerge_abbr();
    &postTokenize();


#    print STDERR $_, "\n";

    s/^\s+//;
    s/\s+$//;

    $copy=$_;
    while($copy=~s/<url>(.*?)<\/url>//) {
	$url=$1;
	$url_no_space=$url;
#	print  "url=$url\n";
	$url=~s/\//\\\//g;
	$url=~s/\?/\\\?/g;
	$url=~s/\&/\\\&/g;
	$url=~s/\%/\\\%/g;
	$url=~s/\_/\\\_/g;
	$url=~s/\[/\\\[/g;
	$url=~s/\]/\\\]/g;
        $url=~s/\+/\\\+/g;
        $url=~s/\@/\\\@/g;
 	$url=~s/\./\\\./g;
 	$url=~s/\*/\\\*/g;
	$url_no_space=~s/ +//g;
	$url_no_space=~s/([^ ])\.\.\.\@/$1 ... \@/g;
	$_=~s/<url>$url<\/url>/$url_no_space/g;       
    }
    $_=~s/<\/?url>//g;
   
    tr/[ \r\n]//s; # supress multiple white spaces into single space
    s/^\s+//;

    print OUT;
    print OUT "\n";
}

close(OUT);


sub Estem_contractions(){

    s/n \' (t(\W|$))/ n\'$1/g;
    s/ \' (m(\W|$))/ \'$1/g;
    s/ \' (re(\W|$))/ \'$1/g;
    s/ \' (ll(\W|$))/ \'$1/g;
    s/ \' (ve(\W|$))/ \'$1/g;
    s/ \' (s(\W|$))/ \'$1/g;
    s/ \' (d(\W|$))/ \'$1/g;
}


sub Estem_elision(){
# stems English elisions, except for the ambiguous cases of 's and 'd
    s/Don \'t/Do not/g;
    s/Won \'t/Will not/g;
    s/Can \'t/Can not/g;
    s/Shan \'t/Shall not/g;

    s/don \'t/do not/g;
    s/won \'t/will not/g;
    s/can \'t/can not/g;
    s/shan \'t/shall not/g;

    s/n \'t/n not/g;
    s/ \'m/ am/g;
    s/ \'re/ are/g;
    s/ \'ll/ will/g;
    s/ \'ve/ have/g;

    s/\bcannot\b/can not/g;
}

sub Edelimit_tokens(){
# puts spaces around punctuation and special symbols

# changed this back to the original method -- always separate hyphenated words. (Lopez)
# Separate tokens joined with a dash except when both sides are English letters
#    s/(^|[^a-zA-Z\-])\-([^\-]|$)/$1 - $2/g;
#    s/(^|[^\-])\-([^a-zA-Z\-]|$)/$1 - $2/g;

# stardardize quotes
    s/\'\' /\" /g;
    s/ \`\`/ \"/g;
    s/\'\'$/\"/g;
    s/^\`\`/\"/g;

# put space after any period that's followed by a non-number and non-period
    s/\.([^0-9\.])/\. $1/g;
# put space before any period that's followed by a space or another period,
# unless preceded by another period
# the following space is introduced in the previous command
    s/([^\.])\.([ \.])/$1 \.$2/g;

# put space around sequences of colons and comas, unless they're
# surrounded by numbers or other colons and comas

    s/(\:+)/ $1 /g;
    1 while s/([0-9]+)\s+(\:+)\s+([0-9]+)/$1$2$3/g;

    s/(\,+)/ $1 /g;
    1 while s/([0-9]{1,3})\s+(\,+)\s+([0-9]{3}([^0-9]|$))/$1$2$3/g;

#    s/([0-9:])\:([0-9:])/$1<CLTKN>$2/g;
#    s/\:/ \: /g;
#    s/([0-9]) ?<CLTKN> ?([0-9])/$1\:$2/g;
#    s/([0-9,])\,([0-9,])/$1<CMTKN>$2/g;
#    s/\,/ \, /g;
#    s/([0-9]) ?<CMTKN> ?([0-9])/$1\,$2/g;

# put space before any other punctuation and special symbol sequences
    s/([^ \!])(\!+)/$1 $2/g;
    s/([^ \?])(\?+)/$1 $2/g;
    s/([^ \;])(\;+)/$1 $2/g;
    s/([^ \"])(\"+)/$1 $2/g;
    s/([^ \)])(\)+)/$1 $2/g;
    s/([^ \(])(\(+)/$1 $2/g;
    s/([^ \/])(\/+)/$1 $2/g;
    s/([^ \&])(\&+)/$1 $2/g;
    s/([^ \^])(\^+)/$1 $2/g;
    s/([^ \%])(\%+)/$1 $2/g;
    s/([^ \$])(\$+)/$1 $2/g;
    s/([^ \+])(\++)/$1 $2/g;
    s/([^ \-])(\-+)/$1 $2/g;
    s/([^ \-])(\-{2,})/$1 $2/g;
    s/([^ \#])(\#+)/$1 $2/g;
    s/([^ \*])(\*+)/$1 $2/g;
    s/([^ \[])(\[+)/$1 $2/g;
    s/([^ \]])(\]+)/$1 $2/g;
    s/([^ \{])(\{+)/$1 $2/g;
    s/([^ \}])(\}+)/$1 $2/g;
    s/([^ \>])(\>+)/$1 $2/g;
    s/([^ \<])(\<+)/$1 $2/g;
    s/([^ \_])(\_+)/$1 $2/g;
    s/([^ \_])(\_{2,})/$1 $2/g;
    s/([^ \\])(\\+)/$1 $2/g;
    s/([^ \|])(\|+)/$1 $2/g;
    s/([^ \=])(\=+)/$1 $2/g;
    s/([^ \`])(\`+)/$1 $2/g;
    s/([^ \²])(\²+)/$1 $2/g;
    s/([^ \³])(\³+)/$1 $2/g;
    s/([^ \«])(\«+)/$1 $2/g;
    s/([^ \»])(\»+)/$1 $2/g;
    s/([^ \¢])(\¢+)/$1 $2/g;
    s/([^ \°])(\°+)/$1 $2/g;

# put space after any other punctuation and special symbols sequences
    s/(\!+)([^ \!])/$1 $2/g;
    s/(\?+)([^ \?])/$1 $2/g;
    s/(\;+)([^ \;])/$1 $2/g;
    s/(\"+)([^ \"])/$1 $2/g;
    s/(\(+)([^ \(])/$1 $2/g;
    s/(\)+)([^ \)])/$1 $2/g;
    s/(\/+)([^ \/])/$1 $2/g;
    s/(\&+)([^ \&])/$1 $2/g;
    s/(\^+)([^ \^])/$1 $2/g;
    s/(\%+)([^ \%])/$1 $2/g;
    s/(\$+)([^ \$])/$1 $2/g;
    s/(\++)([^ \+])/$1 $2/g;
    s/(\-+)([^ \-])/$1 $2/g;
    s/(\-{2,})([^ \-])/$1 $2/g;
    s/(\#+)([^ \#])/$1 $2/g;
    s/(\*+)([^ \*])/$1 $2/g;
    s/(\[+)([^ \[])/$1 $2/g;
    s/(\]+)([^ \]])/$1 $2/g;
    s/(\}+)([^ \}])/$1 $2/g;
    s/(\{+)([^ \{])/$1 $2/g;
    s/(\\+)([^ \\])/$1 $2/g;
    s/(\|+)([^ \|])/$1 $2/g;
#    s/(\_+)([^ \_])/$1 $2/g;
    s/(\_{2,})([^ \_])/$1 $2/g;
    s/(\<+)([^ \<])/$1 $2/g;
    s/(\>+)([^ \>])/$1 $2/g;
    s/(\=+)([^ \=])/$1 $2/g;
    s/(\`+)([^ \`])/$1 $2/g;
# s/(\'+)([^ \'])/$1 $2/g;      # do not insert space after forward tic

    s/(\²+)([^ \²])/$1 $2/g;
    s/(\³+)([^ \³])/$1 $2/g;
    s/(\«+)([^ \«])/$1 $2/g;
    s/(\»+)([^ \»])/$1 $2/g;
    s/(\¢+)([^ \¢])/$1 $2/g;
    s/(\°+)([^ \°])/$1 $2/g;

# separate alphabetical tokens
#    s/([a-zA-Z]+)/ $1 /g;
}

sub apostrophe {

    # Additional apostrophe treatment
    s/([^ \"])(\'+)/$1 $2/g; 
    s/(\'+)([^ \"])/$1 $2/g; 

    # Repair Wades-Giles
    s/((^|\W)ch) \' (\w+(\W|$))/$1\'$3/gi;
    s/((^|\W)ts) \' (\w+(\W|$))/$1\'$3/gi;
    s/((^|\W)tz) \' (\w+(\W|$))/$1\'$3/gi;
    s/((^|\W)k) \' (\w+(\W|$))/$1\'$3/gi;
    s/((^|\W)p) \' (\w+(\W|$))/$1\'$3/gi;
    s/((^|\W)t) \' (\w+(\W|$))/$1\'$3/gi;

    # Repair Romance
    s/((^|\W)l) \' (\w+(\W|$))/$1\'$3/gi; 
    s/((^|\W)d) \' (\w+(\W|$))/$1\'$3/gi;

    # Repair Hebrew
    s/((^|\W)b) \' (\w+(\W|$))/$1\'$3/gi;

    # (Lopez) added the "d" and "B" options for words such as Coast d'Ivoire and B'nai Brith.
#    s/([^ \'dB])(\'+)/$1 $2/g;
}


sub Emerge_abbr(){
    s/\s+U\s+\.\s+S\s+\.\s+S\s+\.\s+R\s+\./ U.S.S.R./g;
    s/\s+U\s+\.\s+S\s+\.\s+A\s+\./ U.S.A./g;
    s/\s+P\s+\.\s+E\s+\.\s+I\s+\./ P.E.I./g;
    s/\s+p\s+\.\s+m\s+\./ p.m./g;
    s/\s+a\s+\.\s+m\s+\./ a.m./g;
    s/\s+U\s+\.\s+S\s+\./ U.S./g;
    s/\s+U\s+\.\s+K\s+\./ U.K./g;
    s/\s+B\s+\.\s+C\s+\./ B.C./g;
    s/\s+vol\s+\./ vol./g;
    s/\s+viz\s+\./ viz./g;
    s/\s+v\s+\./ v./g;
    s/\s+\s+terr\s+\./ terr./g;
    s/\s+tel\s+\./ tel./g;
    s/\s+subss\s+\./ subss./g;
    s/\s+subs\s+\./ subs./g;
    s/\s+sub\s+\./ sub./g;
    s/\s+sess\s+\./ sess./g;
    s/\s+seq\s+\./ seq./g;
    s/\s+sec\s+\./ sec./g;
    s/\s+rév\s+\./ rév./g;
    s/\s+rev\s+\./ rev./g;
    s/\s+repl\s+\./ repl./g;
    s/\s+rep\s+\./ rep./g;
    s/\s+rel\s+\./ rel./g;
    s/\s+paras\s+\./ paras./g;
    s/\s+para\s+\./ para./g;
    s/\s+op\s+\./ op./g;
    s/\s+nom\s+\./ nom./g;
    s/\s+nil\s+\./ nil./g;
    s/\s+mr\s+\./ mr./g;
    s/\s+lég\s+\./ lég./g;
    s/\s+loc\s+\./ loc./g;
    s/\s+jur\s+\./ jur./g;
    s/\s+int\s+\./ int./g;
    s/\s+incl\s+\./ incl./g;
    s/\s+inc\s+\./ inc./g;
    s/\s+id\s+\./ id./g;
    s/\s+ibid\s+\./ ibid./g;
    s/\s+hum\s+\./ hum./g;
    s/\s+hon\s+\./ hon./g;
    s/\s+gén\s+\./ gén./g;
    s/\s+etc\s+\./ etc./g;
    s/\s+esp\s+\./ esp./g;
    s/\s+eg\s+\./ eg./g;
    s/\s+eds\s+\./ eds./g;
    s/\s+ed\s+\./ ed./g;
    s/\s+crit\s+\./ crit./g;
    s/\s+corp\s+\./ corp./g;
    s/\s+conf\s+\./ conf./g;
    s/\s+comp\s+\./ comp./g;
    s/\s+comm\s+\./ comm./g;
    s/\s+com\s+\./ com./g;
    s/\s+co\s+\./ co./g;
    s/\s+civ\s+\./ civ./g;
    s/\s+cit\s+\./ cit./g;
    s/\s+chap\s+\./ chap./g;
    s/\s+cert\s+\./ cert./g;
    s/\s+ass\s+\./ ass./g;
    s/\s+arts\s+\./ arts./g;
    s/\s+art\s+\./ art./g;
    s/\s+alta\s+\./ alta./g;
    s/\s+al\s+\./ al./g;
    s/\s+Yes\s+\./ Yes./g;
    s/\s+XX\s+\./ XX./g;
    s/\s+XVIII\s+\./ XVIII./g;
    s/\s+XVII\s+\./ XVII./g;
    s/\s+XVI\s+\./ XVI./g;
    s/\s+XV\s+\./ XV./g;
    s/\s+XIX\s+\./ XIX./g;
    s/\s+XIV\s+\./ XIV./g;
    s/\s+XIII\s+\./ XIII./g;
    s/\s+XII\s+\./ XII./g;
    s/\s+XI\s+\./ XI./g;
    s/\s+X\s+\./ X./g;
    s/\s+Wash\s+\./ Wash./g;
    s/\s+Vol\s+\./ Vol./g;
    s/\s+Vict\s+\./ Vict./g;
    s/\s+Ves\s+\./ Ves./g;
    s/\s+Va\s+\./ Va./g;
    s/\s+VIII\s+\./ VIII./g;
    s/\s+VII\s+\./ VII./g;
    s/\s+VI\s+\./ VI./g;
    s/\s+V\s+\./ V./g;
    s/\s+Univ\s+\./ Univ./g;
    s/\s+Trib\s+\./ Trib./g;
    s/\s+Tr\s+\./ Tr./g;
    s/\s+Tex\s+\./ Tex./g;
    s/\s+Surr\s+\./ Surr./g;
    s/\s+Supp\s+\./ Supp./g;
    s/\s+Sup\s+\./ Sup./g;
    s/\s+Stud\s+\./ Stud./g;
    s/\s+Ste\s+\./ Ste./g;
    s/\s+Stat\s+\./ Stat./g;
    s/\s+Stan\s+\./ Stan./g;
    s/\s+St\s+\./ St./g;
    s/\s+Soc\s+\./ Soc./g;
    s/\s+Sgt\s+\./ Sgt./g;
    s/\s+Sess\s+\./ Sess./g;
    s/\s+Sept\s+\./ Sept./g;
    s/\s+Sch\s+\./ Sch./g;
    s/\s+Sask\s+\./ Sask./g;
    s/\s+ST\s+\./ ST./g;
    s/\s+Ry\s+\./ Ry./g;
    s/\s+Rev\s+\./ Rev./g;
    s/\s+Rep\s+\./ Rep./g;
    s/\s+Reg\s+\./ Reg./g;
    s/\s+Ref\s+\./ Ref./g;
    s/\s+Qué\s+\./ Qué./g;
    s/\s+Que\s+\./ Que./g;
    s/\s+Pub\s+\./ Pub./g;
    s/\s+Phil\s+\./ Phil./g;
    s/\s+Pty\s+\./ Pty./g;
    s/\s+Prov\s+\./ Prov./g;
    s/\s+Prop\s+\./ Prop./g;
    s/\s+Prof\s+\./ Prof./g;
    s/\s+Probs\s+\./ Probs./g;
    s/\s+Plc\s+\./ Plc./g;
    s/\s+Pas\s+\./ Pas./g;
    s/\s+Parl\s+\./ Parl./g;
    s/\s+Pa\s+\./ Pa./g;
    s/\s+Oxf\s+\./ Oxf./g;
    s/\s+Ont\s+\./ Ont./g;
    s/\s+Okla\s+\./ Okla./g;
    s/\s+Nw\s+\./ Nw./g;
    s/\s+Nos\s+\./ Nos./g;
    s/\s+No\s+\./ No./g;
    s/\s+Nfld\s+\./ Nfld./g;
    s/\s+NOC\s+\./ NOC./g;
    s/\s+Mut\s+\./ Mut./g;
    s/\s+Mtl\s+\./ Mtl./g;
    s/\s+Ms\s+\./ Ms./g;
    s/\s+Mrs\s+\./ Mrs./g;
    s/\s+Mr\s+\./ Mr./g;
    s/\s+Mod\s+\./ Mod./g;
    s/\s+Minn\s+\./ Minn./g;
    s/\s+Mich\s+\./ Mich./g;
    s/\s+Mgr\s+\./ Mgr./g;
    s/\s+Mfg\s+\./ Mfg./g;
    s/\s+Messrs\s+\./ Messrs./g;
    s/\s+Mass\s+\./ Mass./g;
    s/\s+Mar\s+\./ Mar./g;
    s/\s+Man\s+\./ Man./g;
    s/\s+Maj\s+\./ Maj./g;
    s/\s+MURRAY\s+\./ MURRAY./g;
    s/\s+MR\s+\./ MR./g;
    s/\s+M\s+\./ M./g;
    s/\s+Ltd\s+\./ Ltd./g;
    s/\s+Ll\s+\./ Ll./g;
    s/\s+Ld\s+\./ Ld./g;
    s/\s+LTD\s+\./ LTD./g;
    s/\s+Jun\s+\./ Jun./g;
    s/\s+Jr\s+\./ Jr./g;
    s/\s+JJ\s+\./ JJ./g;
    s/\s+JA\s+\./ JA./g;
    s/\s+Ir\s+\./ Ir./g;
    s/\s+Int\s+\./ Int./g;
    s/\s+Inst\s+\./ Inst./g;
    s/\s+Ins\s+\./ Ins./g;
    s/\s+Inc\s+\./ Inc./g;
    s/\s+Imm\s+\./ Imm./g;
    s/\s+Ill\s+\./ Ill./g;
    s/\s+IX\s+\./ IX./g;
    s/\s+IV\s+\./ IV./g;
    s/\s+INC\s+\./ INC./g;
    s/\s+III\s+\./ III./g;
    s/\s+II\s+\./ II./g;
    s/\s+I\s+\./ I./g;
    s/\s+Hum\s+\./ Hum./g;
    s/\s+Hon\s+\./ Hon./g;
    s/\s+Harv\s+\./ Harv./g;
    s/\s+Hagg\s+\./ Hagg./g;
    s/\s+HON\s+\./ HON./g;
    s/\s+Geo\s+\./ Geo./g;
    s/\s+Genl\s+\./ Genl./g;
    s/\s+Gen\s+\./ Gen./g;
    s/\s+Gaz\s+\./ Gaz./g;
    s/\s+Fin\s+\./ Fin./g;
    s/\s+Fed\s+\./ Fed./g;
    s/\s+Feb\s+\./ Feb./g;
    s/\s+Fam\s+\./ Fam./g;
    s/\s+Fac\s+\./ Fac./g;
    s/\s+Europ\s+\./ Europ./g;
    s/\s+Eur\s+\./ Eur./g;
    s/\s+Esq\s+\./ Esq./g;
    s/\s+Enr\s+\./ Enr./g;
    s/\s+Eng\s+\./ Eng./g;
    s/\s+Eliz\s+\./ Eliz./g;
    s/\s+Edw\s+\./ Edw./g;
    s/\s+Educ\s+\./ Educ./g;
    s/\s+Dr\s+\./ Dr./g;
    s/\s+Doc\s+\./ Doc./g;
    s/\s+Dist\s+\./ Dist./g;
    s/\s+Dept\s+\./ Dept./g;
    s/\s+Dears\s+\./ Dears./g;
    s/\s+Dal\s+\./ Dal./g;
    s/\s+Ct\s+\./ Ct./g;
    s/\s+Cst\s+\./ Cst./g;
    s/\s+Crim\s+\./ Crim./g;
    s/\s+Cr\s+\./ Cr./g;
    s/\s+Cowp\s+\./ Cowp./g;
    s/\s+Corp\s+\./ Corp./g;
    s/\s+Conv\s+\./ Conv./g;
    s/\s+Cons\s+\./ Cons./g;
    s/\s+Conn\s+\./ Conn./g;
    s/\s+Comp\s+\./ Comp./g;
    s/\s+Comm\s+\./ Comm./g;
    s/\s+Com\s+\./ Com./g;
    s/\s+Colum\s+\./ Colum./g;
    s/\s+Co\s+\./ Co./g;
    s/\s+Cl\s+\./ Cl./g;
    s/\s+Civ\s+\./ Civ./g;
    s/\s+Cir\s+\./ Cir./g;
    s/\s+Chas\s+\./ Chas./g;
    s/\s+Ch\s+\./ Ch./g;
    s/\s+Cf\s+\./ Cf./g;
    s/\s+Cdn\s+\./ Cdn./g;
    s/\s+Cass\s+\./ Cass./g;
    s/\s+Cas\s+\./ Cas./g;
    s/\s+Car\s+\./ Car./g;
    s/\s+Can\s+\./ Can./g;
    s/\s+Calif\s+\./ Calif./g;
    s/\s+Cal\s+\./ Cal./g;
    s/\s+Bros\s+\./ Bros./g;
    s/\s+Bl\s+\./ Bl./g;
    s/\s+Bd\s+\./ Bd./g;
    s/\s+Aust\s+\./ Aust./g;
    s/\s+Aug\s+\./ Aug./g;
    s/\s+Assur\s+\./ Assur./g;
    s/\s+Assn\s+\./ Assn./g;
    s/\s+App\s+\./ App./g;
    s/\s+Am\s+\./ Am./g;
    s/\s+Alta\s+\./ Alta./g;
    s/\s+Admin\s+\./ Admin./g;
    s/\s+Adjut\s+\./ Adjut./g;
    s/\s+APPLIC\s+\./ APPLIC./g;
#my addition -- Mona Diab
    s/\s+Ma\s+\'\s+am/ Ma\'am/g;
    s/\s+ma\s+\'\s+am/ ma\'am/g;
# additional abbreviations -- Christof Monz
    s/\s+([Jj]an)\s+\./ $1\./g;
    s/\s+([Ff]eb)\s+\./ $1./g;
    s/\s+([Mm]ar)\s+\./ $1\./g;
    s/\s+([Aa]pr)\s+\./ $1\./g;
    s/\s+([Jj]un)\s+\./ $1\./g;
    s/\s+([Jj]ul)\s+\./ $1\./g;
    s/\s+([Aa]ug)\s+\./ $1\./g;
    s/\s+([Ss]ep)\s+\./ $1\./g;
    s/\s+([Ss]ept)\s+\./ $1\./g;
    s/\s+([Oo]ct)\s+\./ $1\./g;
    s/\s+([Nn]ov)\s+\./ $1\./g;
    s/\s+([Dd]ec)\s+\./ $1\./g;

    s/\s+([A-Z][a-z]+\s+[A-Z])\s+\.\s+([A-Z])/ $1\. $2/g;

    s/\s+([xv]*i)\s+\./ $1./g;
    s/\s+([xv]*ii)\s+\./ $1./g;
    s/\s+([xv]iii)\s+\./ $1./g;
    s/\s+([xv]*i[vx])\s+\./ $1./g;    
    
    s/\s+([Ff]r)\s+\./ $1./g;
    s/\s+([Ff]t)\s+\./ $1./g;
    s/\s+([Mt]t)\s+\./ $1./g;
    s/\s+([Rr]ev)\s+\./ $1./g;
    s/\s+(mrs)\s+\./ $1./g;
    s/\s+([Cc]pl)\s+\./ $1./g;    
}


sub postTokenize{
    # Following two lines capture abbreviations such as P.E.R.L.
#    s/(^|\s+)([^\.\s])\s*\.\s*([^\.\s])\s*\./ $2\.$3\. /g;
#    1 while s/([^\.\s]\.[^\.\s]\.)\s+([^\.\s])\s*[\.\s]/$1$2\. /g;

  # the previous turned out to be slightly too permissive, e.g. "D.C.," became "D.C.,.", should have been "D.C. ,"
    s/(^|\s+)([^\.\s])\s*\.\s*([^\.\s])\s*\./ $2\.$3\./g;
    1 while s/([^\.\s]\.[^\.\s]\.)\s+([^\.\s])\s*\./$1$2\./g;

    # Separate the last period
    s/\.\s*$/ \./g;

    # Convert 3 or more of -, _, =, +, #, or * with two of the same symbol
    s/\-{3,}/\-\-/g;
    s/\_{3,}/\_\_/g;
    s/\={3,}/\=\=/g;
    s/\+{3,}/\+\+/g;
    s/\#{3,}/\#\#/g;
    s/\*{3,}/\*\*/g;

    # additional 'special' words -- Christof Monz
    # the following 2 regexes deal with words like "Shi'a":
    s/\s+([A-Za-z]+[aeiouy])\s+\'\s+([aeiouy])/ $1\'$2/g;
    s/^([A-Za-z]+[aeiouy])\s+\'\s+([aeiouy])/$1\'$2/g;

    # don't tokenize urls:
#    s/\s+([A-Za-z]+)\s+\.\s+(com|net|org|de|nl|kg|kz|uk)/ $1.$2/g;
#    s/^([A-Za-z]+)\s+\.\s+(com|net|org|de|nl|kg|kz|uk)/$1.$2/g;

    # don't tokenize initial letters.
    s/^(\s*[A-Z]) \./$1\./g;
    s/([\.\(\[\"\']\s*[A-Z]) \./$1\./g;

    # fix initials of middle names:
    s/\s+([A-Z][a-z]+)\s+([A-Z])\s+\.\s+([A-Z][a-z]+)/ $1 $2. $3/g;

    # fix "..."
    s/\s+\.\s+\.\s+\.\s+/ ... /g;

    #Christof: fixed this to deal with begin and end tags
    s/^\s*< s > /<s> /;
    s/ < \/ s >\s*$/ <\/s>/;
    s/< p >/<p>/;
    s/< \/ p >/<\/p>/;
    s/< url > /<url>/g;
    s/ < \/ url >/<\/url>/g;

}
