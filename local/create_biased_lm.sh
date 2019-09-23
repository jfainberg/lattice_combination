#!/bin/bash
# Copyright 2019    Joachim Fainberg
# Apache 2.0.

set -e

# Create biased LM to some data

stage=0
lambda=0.5
cleanup=true

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
   echo "Usage: local/create_biased_lm.sh <data> <original-lm> <biased-lm>"
   echo " e.g.: create_biased_lm.sh data/adapt data/local/lm/lm.gz data/local/lm/biased_lm.gz"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --stage <stage>                                  # stage to do partial re-run from."
   exit 1;
fi

data=$1
lm=$2
out_lm=$3

tmp_dir=`mktemp -d`

echo "$0: Creating biased LM with $data and $lm"

for f in $lm $data/text; do
  [ ! -f $f ] && echo "create_biased_lm.sh: no such file $f" && exit 1;
done

cut -d" " -f2- $data/text > $tmp_dir/text.sent

echo "Counting ngrams in adaptation data..."
ngram-count -order 3 -interpolate -sort \
    -text $tmp_dir/text.sent -lm $tmp_dir/adapt.3gm.arpa

echo "Interpolating 1 gram LMs..."
ngram -order 1 -lm $lm \
    -mix-lm $tmp_dir/adapt.3gm.arpa \
    -lambda $lambda \
    -write-lm $tmp_dir/adapt.${lambda}.1gm.arpa

# Updated vocab
tail -n +6 $tmp_dir/adapt.${lambda}.1gm.arpa \
    | head -n -2 | sort | cut -f 2 | head -150000 | grep -v '</s>' \
    | sort > $tmp_dir/150k.wlist

echo "Interpolating 3 gram LMs with 150k vocab list from interpolated 1 gram LM..."
ngram -order 3 -lm $lm \
    -mix-lm $tmp_dir/adapt.3gm.arpa \
    -lambda $lambda \
    -vocab $tmp_dir/150k.wlist \
    -limit-vocab -write-lm $tmp_dir/adapt.${lambda}.150k.3gm.arpa.gz

echo "Pruning biased LM..."
prune-lm --threshold=1e-7 $tmp_dir/adapt.${lambda}.150k.3gm.arpa.gz /dev/stdout | gzip -c > $out_lm

if $cleanup; then
    rm -r $tmp_dir
fi

echo "Finished creating biased LM $out_lm" && exit 0
