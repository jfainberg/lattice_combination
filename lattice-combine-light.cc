// latbin/lattice-combine-light.cc

// Copyright 2019 Joachim Fainberg  Edinburgh University
//
// Some code from lattice-oracle.cc, with copyrights:
// Copyright 2011 Gilles Boulianne
//           2013 Johns Hopkins University (author: Daniel Povey)
//           2015 Guoguo Chen

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.

// This program is for combining inaccurate transcriptions with hypothesis
// lattices as described in: "Lattice-based lightly-supervised acoustic model training",
// Joachim Fainberg, Ondrej Klejch, Steve Renals and Peter Bell, Interspeech, 2019.

#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "lat/kaldi-lattice.h"

namespace kaldi {

// Returns false if res has no output symbols in
// common with the input symbols of hyp
bool OverlappingSymbols(const fst::StdVectorFst &ref,
                        const fst::StdVectorFst &hyp) {
  typedef fst::StdArc::Label Label;
  std::vector<Label> ref_syms, hyp_syms, intersection;
  GetOutputSymbols(ref, false /*no epsilons*/, &ref_syms);
  GetInputSymbols(hyp, false /*no epsilons*/, &hyp_syms);
  
  std::sort(ref_syms.begin(), ref_syms.end());
  std::sort(hyp_syms.begin(), hyp_syms.end());

  std::set_intersection(ref_syms.begin(), ref_syms.end(),
                        hyp_syms.begin(), hyp_syms.end(),
                        back_inserter(intersection));

  return ! intersection.empty();
}

// Similar to ScaleLattice in fstext/lattice-utils-inl.h
// but scales FST with single weights
void ScaleFst(fst::StdVectorFst *fst, BaseFloat scale) {
  typedef fst::StdArc Arc;
  typedef fst::MutableFst<Arc> Fst;
  typedef typename Arc::StateId StateId;
  typedef fst::StdArc::Weight Weight;

  StateId num_states = fst->NumStates();
  for (StateId s = 0; s < num_states; s++) {
    for (fst::MutableArcIterator<Fst> aiter(fst, s);
         !aiter.Done();
         aiter.Next()) {
      Arc arc = aiter.Value();
      arc.weight = Weight(arc.weight.Value() * scale);
      aiter.SetValue(arc);
    }
    Weight final_weight = fst->Final(s);
    if (final_weight != Weight::Zero())
      fst->SetFinal(s, Weight(final_weight.Value() * scale));
  }
}

// From lattice-oracle.cc, but with custom costs.
void CreateEditDistance(const fst::StdVectorFst &fst1,
                        const fst::StdVectorFst &fst2,
                        fst::StdVectorFst *pfst,
                        BaseFloat correct_cost_val,
                        BaseFloat substitution_cost_val,
                        BaseFloat insertion_cost_val,
                        BaseFloat deletion_cost_val) {
  typedef fst::StdArc StdArc;
  typedef fst::StdArc::Weight Weight;
  typedef fst::StdArc::Label Label;
  Weight correct_cost(correct_cost_val);
  Weight substitution_cost(substitution_cost_val);
  Weight insertion_cost(insertion_cost_val);
  Weight deletion_cost(deletion_cost_val);

  // create set of output symbols in fst1
  std::vector<Label> fst1syms, fst2syms;
  GetOutputSymbols(fst1, false /*no epsilons*/, &fst1syms);
  GetInputSymbols(fst2, false /*no epsilons*/, &fst2syms);

  pfst->AddState();
  pfst->SetStart(0);
  for (size_t i = 0; i < fst1syms.size(); i++)
    pfst->AddArc(0, StdArc(fst1syms[i], 0, deletion_cost, 0));  // deletions

  for (size_t i = 0; i < fst2syms.size(); i++)
    pfst->AddArc(0, StdArc(0, fst2syms[i], insertion_cost, 0));  // insertions

  // stupid implementation O(N^2)
  for (size_t i = 0; i < fst1syms.size(); i++) {
    Label label1 = fst1syms[i];
    for (size_t j = 0; j < fst2syms.size(); j++) {
      Label label2 = fst2syms[j];
      Weight cost(label1 == label2 ? correct_cost : substitution_cost);
      pfst->AddArc(0, StdArc(label1, label2, cost, 0));  // substitutions
    }
  }
  pfst->SetFinal(0, Weight::One());
  ArcSort(pfst, fst::StdOLabelCompare());
}
}

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using fst::VectorFst;
    using fst::StdArc;
    typedef kaldi::int32 int32;
    typedef kaldi::int64 int64;
    typedef StdArc::Weight Weight;
    typedef StdArc::StateId StateId;

    const char *usage =
        "Composes transcriptions with hypothesis lattices.\n"
        "The default operation produces new lattices where the hypothesis lattices\n"
        "have been collapsed onto a transcript word where they match.\n"
        "\n"
        "Usage: lattice-combine-light [options] <ref-lattice-rspecifier> \\\n"
        "                                       <hyp-lattice-rspecifier> \\\n"
        "                                       <out-lattice-wspecifier>\n"
        " e.g.: lattice-combine-light ark:lat.1 ark:lat.2 ark:res.lat\n"
        "\n";

    ParseOptions po(usage);
    bool prune = true;
    BaseFloat prune_multiplier = 0.0;
    bool return_hyp = true;

    po.Register("prune", &prune,
                "Prune result of composition.");
    po.Register("prune-multiplier", &prune_multiplier,
                "Pruning multiplier. Default (0) selects only paths with minimum cost.");
    po.Register("return-hyp", &return_hyp,
                "If there is no overlap between the transcriptions and the hypotheses, "
                "return the hypothesis lattice as is (semi-supervised), "
                "otherwise return empty for that utterance.");

    po.Read(argc, argv);

    if (po.NumArgs() != 3) {
        po.PrintUsage();
        exit(1);
    }

    std::string reference_rspecifier = po.GetArg(1),
        hypothesis_rspecifier = po.GetArg(2),
        result_wspecifier = po.GetArg(3);

    SequentialCompactLatticeReader clat_reader_ref(reference_rspecifier);
    RandomAccessCompactLatticeReader clat_reader_hyp(hypothesis_rspecifier);
    TableWriter<fst::VectorFstHolder> fst_writer(result_wspecifier);

    int32 n_total_lats = 0, n_success = 0, n_missing = 0, n_no_overlap = 0;

    BaseFloat lm_scale = 0.0;
    BaseFloat acoustic_scale = 0.0;
    fst::vector<fst::vector<double> > scale = fst::LatticeScale(lm_scale, acoustic_scale);


    for (; !clat_reader_ref.Done(); clat_reader_ref.Next()) {
      std::string key = clat_reader_ref.Key();
      n_total_lats++;
      CompactLattice clat_ref = clat_reader_ref.Value();

      ScaleLattice(scale, &clat_ref); // typically scales to zero.
      RemoveAlignmentsFromCompactLattice(&clat_ref); // is this necessary?
      VectorFst<StdArc> fst_ref;
      {
          Lattice lat_ref;
          ConvertLattice(clat_ref, &lat_ref); // convert to non-compact form, won't introduce
          // extra states because already removed alignments
          ConvertLattice(lat_ref, &fst_ref); // adds up lm, acoustic costs to get normal tropical costs
          fst::Project(&fst_ref, fst::PROJECT_OUTPUT); // because we want word labels
      }


      if (clat_reader_hyp.HasKey(key)) {
        CompactLattice clat_hyp = clat_reader_hyp.Value(key);
        n_success++;

        ScaleLattice(scale, &clat_hyp); // typically scales to zero.
        RemoveAlignmentsFromCompactLattice(&clat_hyp); // is this necessary?
        VectorFst<StdArc> fst_hyp;
        {
          Lattice lat_hyp;
          ConvertLattice(clat_hyp, &lat_hyp); // convert to non-compact form, won't introduce
          // extra states because already removed alignments
          ConvertLattice(lat_hyp, &fst_hyp); // adds up lm, acoustic costs to get normal tropical costs
          fst::Project(&fst_hyp, fst::PROJECT_OUTPUT); // because we want word labels
        }

        bool overlap = OverlappingSymbols(fst_ref, fst_hyp);

        if (overlap) {
            KALDI_LOG << "Composing key " << key;

            fst::StdVectorFst edit_distance_fst;
            CreateEditDistance(fst_ref, fst_hyp, &edit_distance_fst, -1.0, 0.0, 0.0, 0.0);

            // compose(transcription, edit)
            VectorFst<StdArc> edit_ref_fst;
            fst::ArcSort(&fst_ref, fst::StdOLabelCompare());
            fst::Compose(fst_ref, edit_distance_fst, &edit_ref_fst);

            // compose(transcription+edit, hypotheses)
            fst::ArcSort(&fst_hyp, fst::StdILabelCompare());
            VectorFst<StdArc> result_fst;
            fst::Compose(edit_ref_fst, fst_hyp, &result_fst);

            if (prune) {
                KALDI_LOG << "Pruning with multiplier " << prune_multiplier;
                fst::Prune(&result_fst, prune_multiplier);
            }

            // Select hypotheses over transcription where there was no match
            fst::Project(&result_fst, fst::PROJECT_OUTPUT);

            fst::RmEpsilon(&result_fst);
            ScaleFst(&result_fst, 0.0);

            VectorFst<StdArc> det_fst;
            fst::Determinize(result_fst, &det_fst);

            fst::Minimize(&det_fst);

            fst_writer.Write(key, det_fst);
        } else {
            if (! overlap) {
                KALDI_WARN << "No overlapping symbols between ref and hyp for " << key;
                n_no_overlap++;
            }
            if (return_hyp) {
                KALDI_LOG << "Returning hypothesis for " << key;
                fst_writer.Write(key, fst_hyp);
            }
        }

      } else {
          KALDI_WARN << "No lattice found for hypothesis utterance " << key;
          n_missing++;
      }
    }

    KALDI_LOG << "Processed successfully " << n_success << " out of "
              << n_total_lats << " with " << n_missing << " missing lats in hypothesis "
              << "(returned " << n_no_overlap << " lats without overlap).";

  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
} // main
