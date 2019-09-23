// latbin/fsts-compose.cc

// Copyright 2019 Joachim Fainberg  Edinburgh University
//
// Based on lattice-compose.cc, with copyright:
// Copyright 2009-2011  Microsoft Corporation;  Saarland University

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


#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/fstext-lib.h"
#include "fstext/table-matcher.h"
#include "fstext/fstext-utils.h"
#include "fstext/kaldi-fst-io.h"

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    using namespace fst;
    typedef kaldi::int32 int32;
    typedef kaldi::int64 int64;
    using fst::SymbolTable;
    using fst::VectorFst;
    using fst::StdArc;

    const char *usage =
        "Like fstcompose, but composes archives of fsts (stored in scp/ark with uttids).\n"
        "\n"
        "Usage: fsts-compose [options] fst-rspecifier1 "
        "fst-rxfilename2 fst-wspecifier\n"
        " e.g.: fsts-compose ark:1.fsts G.fst ark:composed.fsts\n";

    ParseOptions po(usage);

    int32 phi_label = fst::kNoLabel; // == -1
    po.Register("phi-label", &phi_label, "If >0, the label on backoff arcs of the LM");
    po.Read(argc, argv);

    if (po.NumArgs() != 3) {
      po.PrintUsage();
      exit(1);
    }

    KALDI_ASSERT(phi_label > 0 || phi_label == fst::kNoLabel); // e.g. 0 not allowed.

    std::string fst_rspecifier = po.GetArg(1),
        fst_rxfilename = po.GetArg(2),
        fst_wspecifier = po.GetArg(3);
    int32 n_done = 0, n_fail = 0;

    SequentialTableReader<VectorFstHolder> fst_reader(fst_rspecifier);
    TableWriter<VectorFstHolder> fst_writer(fst_wspecifier);
    
    VectorFst<StdArc> *fst2 = fst::ReadFstKaldi(fst_rxfilename);

    if (fst2->Properties(fst::kILabelSorted, true) == 0) {
      // Make sure fst2 is sorted on ilabel.
      fst::ILabelCompare<StdArc> ilabel_comp;
      ArcSort(fst2, ilabel_comp);
    }
    if (phi_label > 0)
      PropagateFinal(phi_label, fst2);

    for (; !fst_reader.Done(); fst_reader.Next()) {
      std::string key = fst_reader.Key();
      KALDI_VLOG(1) << "Processing fst for key " << key;
      VectorFst<StdArc> fst = fst_reader.Value();
      fst::OLabelCompare<StdArc> olabel_comp;
      ArcSort(&fst, olabel_comp);
      VectorFst<StdArc> composed_fst;
      if (phi_label > 0) PhiCompose(fst, *fst2, phi_label, &composed_fst);
      else fst::Compose(fst, *fst2, &composed_fst);

      if (composed_fst.Start() == fst::kNoStateId) {
        KALDI_WARN << "Empty fst for utterance " << key << " (incompatible LM?)";
        n_fail++;
      } else {
        fst_writer.Write(key, composed_fst);
        n_done++;
      }
    }

    KALDI_LOG << "Done " << n_done << " fsts; failed for "
              << n_fail;
    return (n_done != 0 ? 0 : 1);
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
