#!/usr/bin/env bash

#  Container version of pipeline (IRSB-integrator.sh).
#  From transcription to collation (xml > xmlwf > uconv > tpen2tei > collatex > stemmarest upload).
#  Container is a ubuntu image with Java and Python 3 installed.
#
#
#  Created by Violeta on 13.11.2019


#check arguments
if [[ ($# -lt 2) || ($# -ge 3 && $3 != "-m" ) ]]
then
    printf "Usage:\tinputfolder outputfolder [-m]"
    printf "\n\tinputfolder \t-- path to XML transcription files"
    printf "\n\toutputfolder \t-- path to destination folder (will be generated if needed)"
    printf "\n\toptionnal -m flag \t-- treat milestones one by one"
    exit 0
fi

export INPUT=$1

export OUTPUT=$2
if [ -d "$OUTPUT" ]; then rm -rf $OUTPUT; fi
mkdir $OUTPUT

export MST_FLAG=""
if [ ! -z "$3" ] # not empty
  then export MST_FLAG=$3
fi

# path to tools/resources
export TPEN2TEI_PATH=(/tpen2tei)
export NORM_MOD=($TPEN2TEI_PATH/Milestones.Milestones) #Milestones/Milestones.py
export COLLATEX=(/collatex/collatex-tools/target/collatex-tools-1.8-SNAPSHOT.jar) # collatex jar
MILESTONE_FILE="milestones.csv"
MILESTONE_JSON="milestones.json"
ABBR_FILE="abbr.csv"
INDEX_FILE="index.txt"
STEMMAREST_FILE="stemmaresturl.txt"
USER_FILE="user.txt"
RELATION_FILE="relations.txt"
DEFAULT_USER="user@example.org"
DEFAULT_PASS="d0d4f76c2ba30e1eb0bdfe544df5ec8e6951872106eb1bd3d7f9208993f28c69"
DEFAULT_URL="http://stemmarest:8080/stemmarest"

export STEMMAREST_URL=""
if [ -f $STEMMAREST_FILE ] # file exists
then
    read STEMMAREST_URL < $STEMMAREST_FILE
    printf "\n$STEMMAREST_FILE file found; URL read: $STEMMAREST_URL\n"
else
    STEMMAREST_URL=$DEFAULT_URL
    printf "$STEMMAREST_URL\n" > $STEMMAREST_FILE
fi

if [ ! -f $INDEX_FILE ] # index file does not exist
then
    # take all XML files in INPUT folder; create index.txt
    printf "\nScanning current directory..."
    find $INPUT -name "*.xml" >> $INDEX_FILE
else
    printf "\n$INDEX_FILE file found; number of lines read: `grep -c '' $INDEX_FILE`"
fi

if [ -f $USER_FILE ] # user file exists
then
    printf "\n$USER_FILE file found; number of lines read: `grep -c '' $USER_FILE`"
fi

if [ -f $RELATION_FILE ] # relation file exists
then
    printf "\n$RELATION_FILE file found."
else
    printf "\nUsing default relations..."
    cp /relations.txt .
fi
printf "\nNumber of lines read: `grep -c '' $RELATION_FILE`"

if [ ! -f $INDEX_FILE ] # index file still does not exist
then
    printf "\nNo input files found."
    exit 0
fi

if grep ".xml" $INDEX_FILE | wc -l | grep -qw "0";
then
    printf "\nNo XML files found."
    exit 0
else
    printf "\nXML files: `grep \".xml\" $INDEX_FILE | wc -l | xargs`"
fi

if [ ! -d "$OUTPUT/1-wf/" ]; then mkdir $OUTPUT/1-wf/; else rm $OUTPUT/1-wf/*; fi
if [ ! -d "$OUTPUT/1-nwf/" ]; then mkdir $OUTPUT/1-nwf/; else rm $OUTPUT/1-nwf/*; fi
if [ ! -d "$OUTPUT/2-pre/" ]; then mkdir $OUTPUT/2-pre/; else rm $OUTPUT/2-pre/*; fi

# XMLWF
printf "\n\nChecking well-formedness..."
for file in `grep ".xml" $INDEX_FILE`
do
    if [ -f $file ]
    then
        # file exists
        if xmlwf $file | wc -l | grep -qw "0"; #well-formed
        then
            cp $file $OUTPUT/1-wf/
        else
            cp $file $OUTPUT/1-nwf/
        fi
    fi
done
printf "\n`find $OUTPUT/1-wf/ -name "*.xml" | wc -l` well-formed file(s) found\n"
ls $OUTPUT/1-wf/

printf "\n`find $OUTPUT/1-nwf/ -name "*.xml" | wc -l` ill-formed file(s) found\n"
ls $OUTPUT/1-nwf/

if [ ! `find $OUTPUT/1-nwf/ -name "*.xml" | wc -l | xargs` == 0 ] ; then
    printf "\n\nError: Ill-formed files found. Stopping.\n";
    exit 0;
fi

# xml:id check (must be present and non-empty)
printf "\n\nChecking problematic sigla..."
siglas_ok=true;
for file in `ls $OUTPUT/1-wf/`
do
    if `grep -qE "xml:id=\"[^ ]+\"" $OUTPUT/1-wf/$file`; # sigil exists and is not empty and does not contain space
    then
        cp $OUTPUT/1-wf/$file $OUTPUT/2-pre/
    else
        printf "\n\t$file"
        siglas_ok=false
    fi
done
if [ ! "$siglas_ok" = true ]  ; then printf "\nWarning: Problematic siglas found; corresponding transcriptions will be ignored." ; fi;
# ls $OUTPUT/2-pre/

# Check duplicate siglas
touch tmpsiglas
for file in `find $OUTPUT/2-pre/ -name "*.xml"`; do
      printf "`sed -rn 's/.*xml:id="([^"]*)".*/\1/p' $file | xargs`\n" >> tmpsiglas
done

if [ ! "$(wc -l tmpsiglas | awk '{print $1}')" -eq "$(sort -u tmpsiglas | wc -l)" ] ; then
    printf "\n\nError (grave): Duplicate sigla found (see below). Collation would make no sense. Stopping.\n";
    printf "`sort tmpsiglas | uniq -c | awk '{if($1>1) {print "\tSigil <" $2 "> occurs "$1 " times"}}'`\n"
    rm tmpsiglas
    exit 0;
fi
rm tmpsiglas

if [ `find $OUTPUT/2-pre/ -name "*.xml" | wc -l | xargs` == 0 ] ; then
    printf "\n\nError (grave): No files left to process; all files have issues. Stopping.\n";
    exit 0;
fi

printf "\nProcessing `find $OUTPUT/2-pre/ -name "*.xml" | wc -l | xargs` file(s)\n"
# UCONV
printf "\nUnicode normalization...\n"
for file in `ls $OUTPUT/2-pre/`
do
    uconv -x any-nfc -f UTF-8 -o tmpuconv $OUTPUT/2-pre/$file && mv tmpuconv $OUTPUT/2-pre/$file
done

#TPEN2TEI
printf "\nPre-processing XML files..."

printf "\n\tRemoving DOCTYPE declaration"
for file in `ls $OUTPUT/2-pre/`
do
    #printf $file
    sed -i '/DOCTYPE/d' $OUTPUT/2-pre/$file
    printf "."
done

printf "\n\tAdding namespace declaration"
for file in `ls $OUTPUT/2-pre/`
do
    #printf $file
    sed -i 's/<TEI>/<TEI xmlns=\"http:\/\/www.tei-c.org\/ns\/1.0\">/' $OUTPUT/2-pre/$file
    printf "."
done

# artificially add a blank to mark the end of the word,
# whenever the transcribed line ends with <lb> (and is not followed by word continuation)
printf "\n\tInserting space between words separated by lb and newline (word pb|cb? lb newline)"
for file in `ls $OUTPUT/2-pre/`
do
  sed -r -i 's/([^ ])(<pb .*\/> *<lb n="[[:alnum:]]*" *\/>$)/\1 \2/g' $OUTPUT/2-pre/$file # word pb lb newline: add space after word
  sed -r -i 's/([^ ])(<cb .*\/> *<lb n="[[:alnum:]]*" *\/>$)/\1 \2/g' $OUTPUT/2-pre/$file # word cb lb newline: add space after word
  sed -r -i 's/([^ ])(<lb n="[[:alnum:]]*" *\/>$)/\1 \2/g' $OUTPUT/2-pre/$file # word lb newline: add space after word
  sed -r -i 's/([^ ])(<lb *\/>$)/\1 \2/g' $OUTPUT/2-pre/$file # idem, when lb has no n attribute

  sed -r -i 's/([^ ])(<lb n="[[:alnum:]]*" *\/>)\s/\1 \2/g' $OUTPUT/2-pre/$file # word lb space: move space after word
  sed -r -i 's/([^ ])(<lb *\/>)\s/\1 \2/g' $OUTPUT/2-pre/$file # idem, when lb has no n attribute
  printf "."
done

printf "\n\tSame (between word & newline lb)"
for file in `ls $OUTPUT/2-pre/`
do
  sed -r -i 's/(^<lb\/>)/ \1/g' $OUTPUT/2-pre/$file # newline lb : insert space before lb
  sed -r -i 's/(^<lb n=".*" *\/>)/ \1/g' $OUTPUT/2-pre/$file # same, when lb has n attribute
  printf "."
done

printf "\n\tInserting space at the beginning of paragraphs"
for file in `ls $OUTPUT/2-pre/`
do
  sed -r -i 's/(<\/[pP]>)/\1 /g' $OUTPUT/2-pre/$file # add space after </p> or </P>
  sed -r -i 's/(<[pP]>)/\1 /g' $OUTPUT/2-pre/$file # add space after <p> or <P>
  printf "."
done

printf "\n\tInserting space between abbr separated by newline only"
for file in `ls $OUTPUT/2-pre/`
do
  sed -r -i ':a;N;$!ba;s/\n/ÿÿÿ/g' $OUTPUT/2-pre/$file
  sed -r -i 's/(<\/abbr>)(ÿÿÿ[[:space:]]+<abbr)/\1 \2/g' $OUTPUT/2-pre/$file
  sed -r -i 's/ÿÿÿ/\n/g' $OUTPUT/2-pre/$file
  # circumvent match across lines
  printf "."
done

# printf "\n\tInserting space between choice separated by newline only"
for file in `ls $OUTPUT/2-pre/`
do
  sed -r -i ':a;N;$!ba;s/\n/ÿÿÿ/g' $OUTPUT/2-pre/$file
  sed -r -i 's/(<\/choice>)(ÿÿÿ[[:space:]]+<choice)/\1 \2/g' $OUTPUT/2-pre/$file
  sed -r -i 's/ÿÿÿ/\n/g' $OUTPUT/2-pre/$file
  # circumvent match across lines
  # printf "."
done

# printf "\n\tInserting space between seg separated by newline only"
for file in `ls $OUTPUT/2-pre/`
do
  sed -r -i ':a;N;$!ba;s/\n/ÿÿÿ/g' $OUTPUT/2-pre/$file
  sed -r -i 's/(<\/seg>)(ÿÿÿ[[:space:]]+<seg)/\1 \2/g' $OUTPUT/2-pre/$file
  sed -r -i 's/ÿÿÿ/\n/g' $OUTPUT/2-pre/$file
  # circumvent match across lines
  # printf "."
done

if [ ! -f $ABBR_FILE ]
then
  printf "\nResetting abbreviation file"
  cp /tpen2tei/Milestones/abbr.csv .
fi

if [ "$MST_FLAG" == "-m" ]
then
  if [ ! -s $MILESTONE_FILE ] # milestone file does not exists or is empty
  then
      printf "\n\nAutomatically retrieving milestones list..."
      for file in `ls $OUTPUT/2-pre/`
      do
        sed -n 's/.*milestone n="\([^"]*\).*/\1/p'  $OUTPUT/2-pre/$file >> $MILESTONE_FILE
      done

      if [ ! -s $MILESTONE_FILE ] ; then
        # printf "\nError (grave): Milestones missing from trascriptions. Stopping.\n"; exit 0;

        # Automatically insert <milestone> tag after the first <div>
        printf "\nNo milestones found. Automatically inserting <milestone> tag after the first <div>..."
        for file in `ls $OUTPUT/2-pre/`
        do
          sed -i '0,/<div>/{s/<div>/<div><milestone n=\"1\" \/>/}' $OUTPUT/2-pre/$file
          sed -n 's/.*milestone n="\([^"]*\).*/\1/p'  $OUTPUT/2-pre/$file >> $MILESTONE_FILE
        done
      fi
      sort -u -o $MILESTONE_FILE $MILESTONE_FILE
  fi

  if [ -s $MILESTONE_FILE ]
  then
    printf "\nMilestones found: `cat $MILESTONE_FILE | wc -l | xargs`" # xargs to remove spaces
  else
    printf "No milestone found."
    MST_FLAG=""
  fi
fi

if [ ! -d "$OUTPUT/3-collatex-input/" ]; then mkdir $OUTPUT/3-collatex-input/; else rm $OUTPUT/3-collatex-input/*; fi
if [ "$MST_FLAG" == "-m" ]
then
  # printf "\n\tMilestone creation and tokenization using teixml2collatex.py..."
  printf "\n\nRunning TEIXML2COLLATEX...\n"
  python3 $TPEN2TEI_PATH/teixml2collatex.py $OUTPUT/2-pre/ $OUTPUT/3-collatex-input/ -c $NORM_MOD
  printf "\nMILESTONES (JSON): `ls -l $OUTPUT/3-collatex-input/milestone* | wc -l | xargs` (See $OUTPUT/3-collatex-input/)\n"

  printf "\nGenerating special file for milestone collation (milestones.json)...\n"
  > $MILESTONE_JSON
  printf "\n{\"witnesses\": [" >> $MILESTONE_JSON
  for file in `find $OUTPUT/2-pre/ -name "*.xml"`; do
    if `grep -qE "milestone\sn=\".+\"" $file`; then # file contains milestones
        printf "{\"id\": \"`sed -rn 's/.*xml:id="([^"]*)".*/\1/p' $file | xargs`\"," >> $MILESTONE_JSON

        printf "\"tokens\": [" >> $MILESTONE_JSON
        for milestone in `sed -rn 's/.*milestone\sn="([^"]*)".*/\1/p' $file`
        do
          printf "{\"t\": \"$milestone\", \"n\": \"$milestone\", \"lit\": \"$milestone\"}," >> $MILESTONE_JSON;
        done
        sed -i '$s/.$//' $MILESTONE_JSON #delete last char

        printf "]}," >> $MILESTONE_JSON
    fi
  done
  sed -i '$s/.$//' $MILESTONE_JSON #delete last char

  printf "]}" >> $MILESTONE_JSON
  jq . $MILESTONE_JSON > $OUTPUT/3-collatex-input/$MILESTONE_JSON
  rm $MILESTONE_JSON
  ls -l $OUTPUT/3-collatex-input/$MILESTONE_JSON
fi
if [ `du -s $OUTPUT/3-collatex-input/ | awk '{print $1}'` -eq 0 ]; then printf "\nError (grave): Tokenization failed. Stopping.\n"; exit 0; fi

#COLLATEX
printf "\nRunning CollateX"
if [ "$MST_FLAG" == "-m" ]
then
  printf " (milestone by milestone)"
fi

if [ ! -d "$OUTPUT/4-collations" ]; then mkdir $OUTPUT/4-collations/; else rm $OUTPUT/4-collations/*; fi

SECONDS=0
for file in `ls $OUTPUT/3-collatex-input/`
do
  # -t for token by token: -t -f json >
  java -jar -Dnashorn.args="--no-deprecation-warning" $COLLATEX $OUTPUT/3-collatex-input/$file -t -f json > $OUTPUT/4-collations/collation-$file
  if [ "$MST_FLAG" == "-m" ]; then printf "."; fi
done
if (( $SECONDS > 3600 )) ; then
    let "hours=SECONDS/3600"
    let "minutes=(SECONDS%3600)/60"
    let "seconds=(SECONDS%3600)%60"
    printf "\nCollateX run time: $hours hour(s), $minutes minute(s) and $seconds second(s)"
elif (( $SECONDS > 60 )) ; then
    let "minutes=(SECONDS%3600)/60"
    let "seconds=(SECONDS%3600)%60"
    printf "\nCollateX run time: $minutes minute(s) and $seconds second(s)"
else
    printf "\nCollateX run time: $SECONDS seconds"
fi
printf "\nFiles (JSON): `ls -l $OUTPUT/4-collations/collation* | wc -l | xargs` (See $OUTPUT/4-collations/)\n"
if [ `du -s $OUTPUT/4-collations/ | awk '{print $1}'` -eq 0 ]; then printf "\nError (grave): Collation failed. Stopping.\n"; exit 0; fi
ls -l $OUTPUT/4-collations/*

if [ -z "$STEMMAREST_URL" ] # empty
then
    printf "\nResults stored to folder: $OUTPUT\n"
    exit 0
fi

#wait for Stemmarest to become available
until $(curl --output /dev/null --silent --head --fail $STEMMAREST_URL); do
  printf '.'
  sleep 5
done

printf "\nUploading collations to Stemmaweb ($STEMMAREST_URL)...\n"

if [ ! -f $USER_FILE ] # user file does not exist
then
  # create file with default user
  printf "$DEFAULT_USER:$DEFAULT_PASS\n" > $USER_FILE
  printf "\nUser created: $DEFAULT_USER (default)\n"
fi

if [ ! -f $RELATION_FILE ] # relation file does not exist
then
  # create file with default relation
  printf "token-normal-form:This is a reading with the same normal form.\n" > $RELATION_FILE
fi

#create user(s)
printf "Reading user data from $USER_FILE...\n"
if IFS=":" read USER PASSPHRASE
then
  printf "Creating user <$USER>...\n"
  curl --request PUT --header "Content-Type: application/json" --data '{ "role": "user", "id":"'$USER'", "email":"'$USER'", "passphrase":"'$PASSPHRASE'" }' $STEMMAREST_URL/user/$USER > create-user.response
fi < $USER_FILE

#create tradition (output folder name)
TRADITION_NAME="$(date +%F--%H:%M)"
curl --request POST --form "name=$TRADITION_NAME" --form "public=no" --form "userId=$USER" --form "empty=no" $STEMMAREST_URL/tradition > create-tradition.response

TRADITION_ID=`jq ".tradId" create-tradition.response | sed s/\"//g`

if [ ! -z "$TRADITION_ID" ] # not empty
then
  #upload relations
  printf "Reading relation data from $RELATION_FILE...\n"
  while IFS=":" read RELNAME RELDESC
  do
    printf "Creating relation <$RELNAME>:<$RELDESC>\n"
    curl --request PUT --header "Content-Type: application/json" --data "$(jq --arg name "$RELNAME" --arg desc "$RELDESC" -nc '{name:$name,description:$desc}')" $STEMMAREST_URL/tradition/$TRADITION_ID/relationtype/$RELNAME > create-relation-$RELNAME.response
  done < $RELATION_FILE

  #upload collations (JSON format)
  for i in `ls $OUTPUT/4-collations/*.json`
  do
    SECTION_NAME=$(basename $i)
    curl --request POST --form "name=$SECTION_NAME" --form "file=@$i" --form "filetype=cxjson" $STEMMAREST_URL/tradition/$TRADITION_ID/section;
  done

  printf "\nDone. Check out the results at localhost:3000 (or your own Stemmaweb instance) by connecting with $USER/UserPass.\n"
else
  printf "\nDone. Check out the results in folder $OUTPUT.\n"
fi

# silently move logs to output
mkdir -p $OUTPUT/logs
mv *.response *.log $OUTPUT/logs 2>/dev/null
