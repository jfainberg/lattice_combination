# Lattice-combination algorithm

This repository contains code for our Interspeech 2019 paper titled "[Lattice-Based Lightly-Supervised Acoustic Model Training](https://www.isca-speech.org/archive/Interspeech_2019/pdfs/2533.pdf)". The goal is to create improved lattice supervision, and to make the best use of poor transcripts, by combining inaccurate transcripts with hypothesis lattices generated for semi-supervised training.

The repository also contains a simple script to add deletion penalties (insertion rewards) to the HCLG, in `local/add_penalty_hclg.sh`, as well as a script to generate a biased n-gram LM.

Any questions or problems - please get in touch.

## Installation
This work requires a functioning install of [Kaldi](https://github.com/kaldi-asr/kaldi).

To install, either run `install.sh`, providing the Kaldi root directory:
`bash install.sh /path/to/kaldi`

or follow the equivalent steps below:
1. Place `lattice-combine-light.cc` and `fsts-compose.cc` into `src/latbin/`
2. Edit `src/latbin/Makefile` and add `lattice-combine-light fsts-compose` to the end of the `BINFILES`.
3. Run `make`.

## Usage
The core algorithm is in `lattice-combine-light`. An example usage is included in `local/get_combined_lats.sh`. The output of this script can be supplied as lattices for training with chain models in Kaldi.

The remaining scripts are included to reproduce some experiments from the paper:
 - `local/create_biased_graph.sh` shows one way to bias an existing LM to the training data and generate a new graph.
 - `local/add_penalty_hclg.sh` shows how to apply a deletion penalty / insertion reward to an existing graph.
 
Graph directories resulting from the above scripts can be passed to `local/get_combined_lats.sh`.

## Citation
For research using this work, please cite:
```
@inproceedings{Fainberg2019,
  author={Joachim Fainberg and Ondřej Klejch and Steve Renals and Peter Bell},
  title={{Lattice-Based Lightly-Supervised Acoustic Model Training}},
  year=2019,
  booktitle={Proc. Interspeech 2019},
  pages={1596--1600},
  doi={10.21437/Interspeech.2019-2533},
  url={http://dx.doi.org/10.21437/Interspeech.2019-2533}
}
```
