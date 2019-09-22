#!/bin/bash
# Copyright 2019    Joachim Fainberg
# Apache 2.0.

set -e

# Create biased LM to some data

stage=0
lambda=0.5
prefix=train_b

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

if [ $# != 2 ]; then
   echo "Usage: local/create_biased_lm.sh <data> <original-lm>"
   echo " e.g.: create_biased_lm.sh data/adapt data/local/lm/lm.gz"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --stage <stage>                                  # stage to do partial re-run from."
   exit 1;
fi

data=$1
lm=$2

echo "$0: Creating biased LM with $data and $lm"

for f in $lm $data/text; do
  [ ! -f $f ] && echo "create_biased_lm.sh: no such file $f" && exit 1;
done

cut -d" " -f2- $data/text > $data/text.sent

echo "Counting ngrams in adaptation data..."
ngram-count -order 3 -interpolate -sort \
    -text $data/text.sent -lm $data/adapt.3gm.kn.arpa

echo "Interpolating 1 gram LMs..."
ngram -order 1 -lm $lm \
    -mix-lm $data/adapt.3gm.kn.arpa \
    -lambda $lambda \
    -write-lm $data/train.adapt.${lambda}.1gm.arpa

# Updated vocab
tail -n +6 $data/train.adapt.${lambda}.1gm.arpa \
    | head -n -2 | sort | cut -f 2 | head -150000 | grep -v '</s>' \
    | sort > $data/${prefix}.${lambda}.150k.wlist

echo "Interpolating 3 gram LMs with 150k vocab list from interpolated 1 gram LM..."
ngram -order 3 -lm $lm \
    -mix-lm $data/adapt.3gm.kn.arpa \
    -lambda $lambda \
    -vocab $data/${prefix}.${lambda}.150k.wlist \
    -limit-vocab -write-lm $data/${prefix}.${lambda}.150k.3gm.kn.arpa.gz

echo "Pruning biased LM..."
prune-lm --threshold=1e-7 $data/${prefix}.${lambda}.150k.3gm.kn.arpa.gz /dev/stdout | gzip -c > $data/${prefix}.${lambda}.150k.p07.3gm.kn.arpa.gz

echo "Finished creating biased LM" && exit 0
