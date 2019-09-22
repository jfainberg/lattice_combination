#!/bin/bash
# Copyright 2019    Joachim Fainberg
# Apache 2.0.

# Create biased lang and graph directories

set -e

# Begin configuration section.
lambda=0.5
prefix=train_b
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

if [ $# != 7 ]; then
   echo "Usage: local/create_biased_graph.sh <old-lang-dir> <old-lm-arpa> <lexicon> <new-lang-dir> <data-dir> <old-graph-dir> <new-graph-dir>"
   echo " e.g.: local/create_biased_graph.sh data/lang data/local/lm/lm.full.3gm.kn.arpa.gz data/local/dict/lexicon data/lang_bias data/train exp/tri4/graph exp/tri4/graph_bias"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>     # config containing options"
   exit 1;
fi

oldlang=$1
oldarpa=$2
lexicon=$3
newlang=$4
data=$5
oldgraph=$6
newgraph=$7

if [ ! -d $newgraph ]; then
    echo "$0: Biasing LM directory and graph to $data"

    modeldir= # one up from newgraphdir

    # Creates a new LM stored within $data
    local/create_biased_lm.sh --lambda $lambda --prefix $prefix $data $oldarpa
    newarpa=$data/${prefix}.${lambda}.150k.p07.3gm.kn.arpa.gz

    utils/format_lm.sh $oldlang $newarpa $lexicon $newlang
    utils/mkgraph.sh --self-loop-scale 1.0 $newlang $modeldir $newgraph

    echo "$0: Finished creating biased LM and graph dirs into: $newlang and $newgraph"
else
    echo "$0: Biased graph seems to already exist in $newgraph. Skipping."
fi
