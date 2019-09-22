#!/bin/bash
# Copyright 2018    Joachim Fainberg
# Apache 2.0.

# Add penalties (insertion/deletion) to HCLG

stage=0
penalty=-1 # negative for deletion penalty (insertion reward), positive for insertion penalty

. utils/parse_options.sh

if [ $# != 2 ]; then
  echo "Usage: "
  echo "  $0 [options] <graph-dir> <new-graph-dir>"
  echo "options"
  echo "  --penalty <penalty> # penalty to apply (negative for deletion penalty)"
  echo "  --stage <stage>     # stage to do partial re-run from."
  exit 1;
fi

graphdir=$1
dir=$2

mkdir -p $dir

for f in HCLG.fst  disambig_tid.int  num_pdfs  phones.txt  words.txt; do
  [ ! -f $graphdir/$f ] && echo "$0: no such file $graphdir/$f" && exit 1;
done

if [ $stage -le 0 ]; then
    echo "$0: Writing $dir/HCLG.txt"
    fstprint $graphdir/HCLG.fst $dir/HCLG.txt || exit 1

    echo "$0: Adding penalty of $penalty to word output labels"
    awk -v pen=$penalty '$4>0 { $5=$5+pen } {print $0}' $dir/HCLG.txt > $dir/HCLG_penalized.txt

    echo "$0: Compiling $dir/HCLG.fst"
    fstcompile $dir/HCLG_penalized.txt $dir/HCLG.fst || exit 1
fi

if [ $stage -le 1 ]; then
    # Cleanup and copy remaining files
    for f in disambig_tid.int  num_pdfs  phones.txt  words.txt phones; do
        cp -r $graphdir/$f $dir/
    done

    rm $dir/HCLG.txt $dir/HCLG_penalized.txt
fi

echo "$0: Done adding a penalty of $penalty to HCLG."
