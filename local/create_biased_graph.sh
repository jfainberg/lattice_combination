#!/bin/bash
# Copyright 2019    Joachim Fainberg
# Apache 2.0.

# Create biased lang and graph directories

set -e

# Begin configuration section.
lambda=0.5
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

if [ $# != 8 ]; then
   echo "Usage: local/create_biased_graph.sh <old-lang-dir> <old-lm-arpa> <old-graph-dir> <new-lang-dir> <new-lm-arpa> <new-graph-dir> <lexicon> <data-dir>"
   echo " e.g.: local/create_biased_graph.sh data/lang data/local/lm/3gm.arpa.gz exp/tri4/graph data/lang_bias data/local/lm/3gm.bias.arpa.gz exp/chain/tdnn/graph_bias data/local/dict/lexicon data/train"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>     # config containing options"
   exit 1;
fi

oldlang=$1
oldarpa=$2
oldgraph=$3
newlang=$4
newarpa=$5
newgraph=$6
lexicon=$7
data=$8

modeldir=`dirname $newgraph` # The model directory is assumed one level up from graph directory.

if [ ! -d $newgraph ]; then
    echo "$0: Biasing LM directory and graph to $data"

    local/create_biased_lm.sh --cleanup true --lambda $lambda $data $oldarpa $newarpa

    utils/format_lm.sh $oldlang $newarpa $lexicon $newlang
    utils/mkgraph.sh --self-loop-scale 1.0 $newlang $modeldir $newgraph

    echo "$0: Finished creating biased LM and graph dirs into: $newlang and $newgraph"
else
    echo "$0: Biased graph seems to already exist in $newgraph. Skipping."
fi
