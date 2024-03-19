# Lattice-combination algorithm
[![arXiv](https://img.shields.io/badge/arXiv-1905.13150-b31b1b.svg)](https://arxiv.org/abs/1905.13150)

This repository contains code for our Interspeech 2019 paper titled "[Lattice-Based Lightly-Supervised Acoustic Model Training](https://www.isca-speech.org/archive/Interspeech_2019/pdfs/2533.pdf)". The goal is to create improved lattice supervision, and to make the best use of poor transcripts, by combining inaccurate transcripts with hypothesis lattices generated for semi-supervised training.

The repository also contains a simple script to add deletion penalties (insertion rewards) to the HCLG, as well as a script to generate a biased n-gram LM.

Finally we've included an example of the algorithm using [pyfst](https://pyfst.github.io) in a Python notebook.

Any questions or problems - please get in touch.

This work is the result of a collaboration with my co-authors [Ondrej Klejch](http://www.ondrejklejch.cz), [Peter Bell](http://homepages.inf.ed.ac.uk/pbell1), and [Steve Renals](https://homepages.inf.ed.ac.uk/srenals).

## Installation
This work requires a functioning install of [Kaldi](https://github.com/kaldi-asr/kaldi).

To install, either run `install.sh`, providing the Kaldi root directory:
`bash install.sh /path/to/kaldi`

or follow the equivalent steps below:
1. Place `lattice-combine-light.cc` and `fsts-compose.cc` into `src/latbin/`
2. Edit `src/latbin/Makefile` and add `lattice-combine-light fsts-compose` to the end of the `BINFILES`.
3. Run `make`.

## Usage
The core algorithm is in `lattice-combine-light.cc`. An example usage is included in `local/get_combined_lats.sh`. The output of this script can be supplied as lattices for training with chain models in Kaldi.

The remaining scripts are included to reproduce some experiments from the paper:
 - `local/create_biased_graph.sh` shows one way to bias an existing LM to the training data and generate a new graph.
 - `local/add_penalty_hclg.sh` shows how to apply a deletion penalty / insertion reward to an existing graph.
 
Graph directories resulting from the above scripts can be passed to `local/get_combined_lats.sh`.

See also `lattice_combination_example.ipynb` for an example of how to run the algorithm in a Python notebook.

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
