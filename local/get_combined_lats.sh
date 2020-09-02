#!/bin/bash
# Copyright 2019    Joachim Fainberg
# Apache 2.0.

set -e

# This is an example script of how to use
# lattice-combine-light to generate new lattice supervision
# as the combination of some inaccurate transcripts and their
# corresponding semi-supervised lattices, as described in
# "Lattice-based lightly-supervised acoustic model training",
# Joachim Fainberg, Ondrej Klejch, Steve Renals and Peter Bell, Interspeech, 2019.

# The resulting lattices from this script can be used for training with LF-MMI.

# Begin configuration.
stage=-1
nj=16
cmd=run.pl
decode_opts= # e.g. i-vectors
latcomb_opts="" # passed to lattice-combine-light
lambda=0.7 # LM bias factor
hyp_beam=30
scale_opts='--transition-scale=1.0 --self-loop-scale=1.0'
# End configuration.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

if [ $# != 7 ]; then
   echo "Usage: $0 [opts] <lang-dir> <hires-data-dir> <lores-data-dir> <gmm-dir> <nnet-model-dir> <graph-dir> <output-dir>"
   echo " e.g.: $0 data/lang_bias data/train_hires data/train exp/tri4 exp/chain/tdnn7p exp/chain/tdnn7p/graph_bias_pen-1 exp/chain/tdnn7p/combined_lats"
   echo ""
   echo "Uses a GMM-dir with lores feats to generate transcription lattices,"
   echo "and a seed nnet model with hires feats to generate hypothesis lattices."
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --config <config-file>                           # config containing options"
   echo "  --stage <stage>                                  # stage to do partial re-run from."
   exit 1;
fi

lang=$1
data=$2
data_lo=$3
gmmdir=$4
chain_dir=$5
graph_dir=$6
dir=$7

modeldir=`dirname $dir`; # Assume model directory one level up from output directory.
[ ! -f $modeldir/final.mdl ] && echo "$0: Output-dir should be within a model-dir, e.g. exp/tdnn/output" && exit 1

mkdir -p $dir

for f in $chain_dir/final.mdl $gmmdir/final.mdl $data/feats.scp $data_lo/feats.scp $lang/G.fst $graph_dir/HCLG.fst; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

# Generate transcription and hypothesis lattices
if [ $stage -le 0 ]; then
    # Transcription lattices (ref)
    if [ ! -d ${data_lo}/lats ]; then
        steps/align_fmllr_lats.sh --nj $nj --generate-ali-from-lats true \
          ${data_lo} $lang $gmmdir ${data_lo}/lats
        rm ${data_lo}/lats/fsts.*.gz # save space
    fi

    # Hypothesis lattices (hyp)
    if [ ! -f $dir/lat.1.gz ]; then
        steps/nnet3/decode_semisup.sh $decode_opts --num-threads 1 --nj $nj \
                --acwt 1.0 --post-decode-acwt 10.0 --write-compact true \
                --skip-scoring true --word-determinize false \
                ${graph_dir} $data $dir
    fi
fi

ln -sf `pwd`/${data_lo}/lats $dir/lat_captions

# Combine and create training lats
ref_rspecifier="gunzip -c $dir/lat_captions/lat.JOB.gz | lattice-copy --include=$data/utt2spk ark:- ark:- | lattice-1best ark:- ark:- | lattice-project ark:- ark:- |"
hyp_rspecifier="gunzip -c $dir/lat.JOB.gz | lattice-copy --include=$data/utt2spk ark:- ark:-  |"

if [ $stage -le 1 ]; then
    echo "$0: Combining lightly supervised hypotheses and reference lattices"
    phi=`grep -w '#0' $lang/words.txt | awk '{print $2}'`
    mkdir -p $dir/lat_combined
    $cmd JOB=1:$nj $dir/lat_combined/log/lattice_combine_light.JOB.log \
        lattice-combine-light $latcomb_opts --prune=true \
        ark:"$ref_rspecifier" ark:"$hyp_rspecifier lattice-determinize-pruned --acoustic-scale=0.1 --beam=$hyp_beam ark:- ark:- |" ark:- \
        \| fsts-compose --phi-label=$phi ark:- "fstproject $lang/G.fst|" \
        ark,scp:$dir/lat_combined/lat_comb.JOB.ark,$dir/lat_combined/lat_comb.JOB.scp

    for i in `seq $nj`; do
        cat $dir/lat_combined/lat_comb.$i.scp
    done > $dir/lat_combined/lat_comb.scp

    # This is a custom align_lats.sh with minor changes
    # See header of the script for details
    local/align_lats.sh $decode_opts --nj $nj \
        --acoustic-scale 1.0 \
        --post-decode-acwt 10.0 \
        --scale-opts "$scale_opts" \
        --beam 40.0 --lattice-beam 8.0 \
        --generate-ali-from-lats true \
        --graphs-scp $dir/lat_combined/lat_comb.scp \
        $data $lang $chain_dir $dir/lat_combined
fi

echo "$0: Done creating combined lattices in $dir/lat_combined"
exit 0
