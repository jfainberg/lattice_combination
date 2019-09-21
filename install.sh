#!/bin/bash
# Copyright 2019    Joachim Fainberg
# Apache 2.0.

# This script installs two binaries to Kaldi's source by the following steps:
#   1) Copy binaries to `$KALDI_ROOT/src/latbin/`.
#   2) Amend `$KALDI_ROOT/src/latbin/Makefile` to include the binaries.
#   3) Run `make`.

if [ $# -ne 1 ]; then
  echo "Usage: $0 <KALDI-ROOT>"
  echo "This script installs lattice-combination binaries to Kaldi's source."
  exit 1
fi

KALDI_ROOT=$1

cp lattice-combine-light.cc $KALDI_ROOT/src/latbin/ || exit 1

# Only amend if not already present
if ! grep -q " lattice-combine-light " $KALDI_ROOT/src/latbin/Makefile; then
    sed -i.bak "s:BINFILES =:BINFILES = lattice-combine-light:g" $KALDI_ROOT/src/latbin/Makefile || exit 1
fi

make -C $KALDI_ROOT/src/latbin || exit 1

echo "$0: Finished installing lattice-combine-light"
