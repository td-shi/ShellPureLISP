#!/bin/sh
#
# A Pure LISP interpreter by POSIX-conformant shell
# Evaluator defined in McCarthy's 1960 paper
# with basic functions for conscell operations,
# S-expression input/output and simple REPL
#
# This code is licensed under CC0.
# https://creativecommons.org/publicdomain/zero/1.0/
#


# Basic functions for conscell operations:
# cons, car, cdr, atom, eq

cons () {
  eval CAR$CNUM=$1
  eval CDR$CNUM=$2
  CONSR=${CNUM}.conscell
  CNUM=$((CNUM+1))
}

car () { eval CARR="\$CAR${1%%.*}"; }
cdr () { eval CDRR="\$CDR${1%%.*}"; }

atom () {
  if [ "${1##*.}" = conscell ]; then
    ATOMR=nil
  else
    ATOMR=t
  fi
}

eq () {
  atom $1
  if [ $ATOMR = nil ]; then
    EQR=nil
  else
    atom $2
    if [ $ATOMR = nil ]; then
      EQR=nil
    elif [ "$1" = "$2" ]; then
      EQR=t
    else
      EQR=nil
    fi
  fi
}


# S-expreesion output: s_display

s_strcons () {
  car $1 && s_display $CARR
  cdr $1
  eq $CDRR nil
  if [ $EQR = t ]; then
    echo -n
  else
    atom $CDRR
    if [ $ATOMR = t ]; then
      echo -n " . "$CDRR
    else
      echo -n " " && s_strcons $CDRR
    fi
  fi
}

s_display () {
  eq $1 nil
  if [ $EQR = t ]; then
    echo -n "()"
  else
    atom $1
    if [ $ATOMR = t ]; then
      echo -n $1
    else
      echo -n "("
      s_strcons $1
      echo -n ")"
    fi
  fi
}


# S-expression lexical analysis: s_lex

IFS=''

LF="
"

replace_all_posix() {
  set -- "$1" "$2" "$3" "$4" ""
  until [ _"$2" = _"${2#*"$3"}" ] && eval "$1=\$5\$2"; do
    set -- "$1" "${2#*"$3"}" "$3" "$4" "$5${2%%"$3"*}$4"
  done
}

s_lex0 () {
  replace_all_posix sl0INI " $1 " "$LF" ""
  replace_all_posix sl0LPS "$sl0INI" "(" " ( "
  replace_all_posix sl0RPS "$sl0LPS" ")" " ) "
  replace_all_posix sl0RET "$sl0RPS" "'" " ' "
}

s_lex1 () {
  sl1HEAD=${1%% *}
  sl1REST=${1#* }

  if [ ! ${sl1HEAD} = " " ]; then
    eval "TOKEN$TNUM=\$sl1HEAD"
    TNUM=$((TNUM+1))
  fi

  if [ ! ${sl1REST} = " " ]; then
    s_lex1 $sl1REST
  fi
}

s_lex () { s_lex0 $1 && s_lex1 $sl0RET; }


# S-expression syntax analysis: s_syn

s_quote () {
  if [ $SYNPOS -ge 0 ]; then
    eval "squox=\$TOKEN$SYNPOS"
    if [ $squox = "'" ]; then
      SYNPOS=$((SYNPOS-1))
      cons $1 nil
      cons quote $CONSR
      SQUOTER=$CONSR
    else
      SQUOTER=$1
    fi
  else
    SQUOTER=$1
  fi
}

s_syn0 () {
  eval "ss0t=\$TOKEN$SYNPOS"
  if [ $ss0t = "(" ]; then
    SYNPOS=$((SYNPOS-1))
    SSYN0R=$1
  elif [ $ss0t = "." ]; then
    SYNPOS=$((SYNPOS-1))
    s_syn
    car $1
    cons $SSYNR $CARR
    s_syn0 $CONSR
  else
    s_syn
    cons $SSYNR $1
    s_syn0 $CONSR
  fi
}

s_syn () {
  eval "ssyt=\$TOKEN$SYNPOS"
  SYNPOS=$((SYNPOS-1))
  if [ $ssyt = ")" ]; then
    s_syn0 nil
    s_quote $SSYN0R
    SSYNR=$SQUOTER
  else
    s_quote $ssyt
    SSYNR=$SQUOTER
  fi
}


# Stack implementation for recursive calls

stackpush () {
  eval STACK$STACKNUM=$1
  STACKNUM=$((STACKNUM+1))
}

stackpop ()
{
  STACKNUM=$((STACKNUM-1))
  eval STACKPOPR="\$STACK$STACKNUM"
}


# The evaluator: s_eval and utility functions

caar () {
  car $1
  car $CARR
  CAARR=$CARR
}
cadr () {
  cdr $1
  car $CDRR
  CADRR=$CARR
}
cadar () {
  car $1
  cdr $CARR
  car $CDRR
  CADARR=$CARR
}
caddr () {
  cdr $1
  cdr $CDRR
  car $CDRR
  CADDRR=$CARR
}
caddar () {
  car $1
  cdr $CARR
  cdr $CDRR
  car $CDRR
  CADDARR=$CARR
}

s_null () { eq $1 nil && SNULLR=$EQR; }

s_append () {
  s_null $1
  if [ $SNULLR = "t" ]; then
    SAPPENDR=$2
  else
    cdr $1
    s_append $CDRR $2
    car $1
    cons $CARR $SAPPENDR
    SAPPENDR=$CONSR
  fi
}

s_list () {
  cons $2 nil
  cons $1 $CONSR
  SLISTR=$CONSR
}

s_pair () {
  s_null $1 && spanr=$SNULLR
  s_null $2
  if [ $spanr = t -a $SNULLR = t ]; then
    SPAIRR=nil
  else
    atom $1 && spaatr=$ATOMR
    atom $2
    if [ $spaatr = nil -a $ATOMR = nil ]; then
      cdr $1 && spadr=$CDRR
      cdr $2
      s_pair $spadr $CDRR
      car $1 && spaar=$CARR
      car $2
      s_list $spaar $CARR
      cons $SLISTR $SPAIRR
      SPAIRR=$CONSR
    else
      SPAIRR=nil
    fi
  fi
}

s_assoc () {
  caar $2
  eq $CAARR $1
  if [ $EQR = t ]; then
    cadar $2
    SASSOCR=$CADARR
  else
    cdr $2
    s_assoc $1 $CDRR
  fi
}

s_eval () {
  eq $1 t
  if [ $EQR = t ]; then
    SEVALR=t
  else
  eq $1 nil
  if [ $EQR = t ]; then
    SEVALR=nil
  else
  atom $1
  if [ $ATOMR = t ]; then
    s_assoc $1 $2 && SEVALR=$SASSOCR
  else
  car $1 && atom $CARR
  if [ $ATOMR = t ]; then
    car $1
    case $CARR in
      quote)
        cadr $1 && SEVALR=$CADRR
        ;;
      atom)
        cadr $1 && s_eval $CADRR $2
        atom $SEVALR && SEVALR=$ATOMR
        ;;
      eq)
        caddr $1 && s_eval $CADDRR $2
        stackpush $SEVALR
        cadr  $1 && s_eval $CADRR  $2
        stackpop
        eq $SEVALR $STACKPOPR
        SEVALR=$EQR
        ;;
      car)
        cadr $1 && s_eval $CADRR $2
        car $SEVALR && SEVALR=$CARR
        ;;
      cdr)
        cadr $1 && s_eval $CADRR $2
        cdr $SEVALR && SEVALR=$CDRR
        ;;
      cons)
        caddr $1 && s_eval $CADDRR $2
        stackpush $SEVALR
        cadr  $1 && s_eval $CADRR  $2
        stackpop
        cons $SEVALR $STACKPOPR
        SEVALR=$CONSR
        ;;
      cond)
        cdr $1 && evcon $CDRR $2
        SEVALR=$EVCONR
        ;;
      def)
        caddr $1
        s_eval $CADDRR $2 && cons $SEVALR nil
        stackpush $CONSR
        cadr $1 && cons $CADRR nil
        stackpop
        s_pair $CONSR $STACKPOPR
        s_append $SPAIRR $2
        cons def $SAPPENDR
        SEVALR=$CONSR
        ;;
      null)
        cadr $1 && s_eval $CADRR $2
        s_null $SEVALR && SEVALR=$SNULLR
        ;;
      append)
        caddr $1 && s_eval $CADDRR $2
        stackpush $SEVALR
        cadr  $1 && s_eval $CADRR  $2
        stackpop
        s_append $SEVALR $STACKPOPR
        SEVALR=$SAPPENDR
        ;;
      list)
        caddr $1 && s_eval $CADDRR $2
        stackpush $SEVALR
        cadr  $1 && s_eval $CADRR  $2
        stackpop
        s_list $SEVALR $STACKPOPR
        SEVALR=$SLISTR
        ;;
      pair)
        caddr $1 && s_eval $CADDRR $2
        stackpush $SEVALR
        cadr  $1 && s_eval $CADRR  $2
        stackpopr
        s_pair $SEVALR $STACKPOPR
        SEVALR=$SPAIRR
        ;;
      assocl)
        caddr $1 && s_eval $CADDRR $2
        stackpush $SEVALR
        cadr  $1 && s_eval $CADRR  $2
        stackpop
        s_assoc $SEVALR $STACKPOPR
        SEVALR=$SASSOCR
        ;;
      or)
        cadr $1 && s_eval $CADRR $2
        if [ $SEVALR = t ]; then
          SEVALR=t
        else
          caddr $1 && s_eval $CADDRR $2
        fi
        ;;
      and)
        cadr $1 && s_eval $CADRR $2
        if [ $SEVALR = t ]; then
          caddr $1 && s_eval $CADDRR $2
        else
          SEVALR=nil
        fi
        ;;
      *)
        car $1
        s_assoc $CARR $2
        cdr $1
        cons $SASSOCR $CDRR
        s_eval $CONSR $2
        ;;
    esac
  else
    caar $1
    eq $CAARR lambda
    if [ $EQR = t ]; then
      cdr $1
      evlis $CDRR $2
      cadar $1
      s_pair $CADARR $EVLISR
      s_append $SPAIRR $2
      caddar $1
      s_eval $CADDARR $SAPPENDR
    else
      SEVALR=nil
    fi
  fi
  fi
  fi
  fi
}

evcon () {
  caar $1 && s_eval $CAARR $2
  if [ $SEVALR = t ]; then
    cadar $1 && s_eval $CADARR $2
    EVCONR=$SEVALR
  else
    cdr $1 && evcon $CDRR $2
  fi
}

evlis () {
  s_null $1
  if [ $SNULLR = "t" ]; then
    EVLISR=nil
  else
    cdr $1 && evlis  $CDRR $2
    car $1 && s_eval $CARR $2
    cons $SEVALR $EVLISR
    EVLISR=$CONSR
  fi
}


# Simple REPL

s_replread () {
  SREPLREADR=""
  read srplrd
  while [ ! $srplrd = "\n" ]; do
    SREPLREADR=$SREPLREADR$srplrd
    read srplrd
  done
}

s_repl () {
  if [ ! $PROMPT = nil ]; then
    echo -n "S> "
  fi
  s_replread
  if [ ! $SREPLREADR = exit ]; then
    s_lex $SREPLREADR
    SYNPOS=$((TNUM-1))
    s_syn
    s_eval $SSYNR $ENV
    atom $SEVALR
    if [ $ATOMR = nil ]; then
      car $SEVALR && eq $CARR def
      if [ $EQR = t ]; then
        cdr $SEVALR
        s_append $CDRR $ENV
        ENV=$SAPPENDR
        cdr $SEVALR && car $CDRR && car $CARR
        SEVALR=$CARR
      fi
    fi
    s_display $SEVALR && echo
    s_repl
  fi
}


# exec REPL with initialization

CNUM=0
TNUM=0
STACKNUM=0
ENV=nil
if [ "$1" != "-s" ]; then
  PROMPT=t
else
  PROMPT=nil
fi
s_repl
