require "./spec_helper"
require "../src/similarity"

describe Similarity do
  describe ".calculate_signature" do
    it "is deterministic for the same text" do
      Similarity.calculate_signature("café con leche").should eq(
        Similarity.calculate_signature("café con leche"))
    end

    it "keeps accented words distinct from their stripped forms" do
      # The old ASCII-only tokenizer folded "diseño" into "diseo",
      # making these two texts produce identical signatures.
      accented = Similarity.calculate_signature("diseño diseño diseño")
      stripped = Similarity.calculate_signature("diseo diseo diseo")
      accented.should_not eq(stripped)
    end

    it "keeps non-ASCII words instead of dropping them" do
      # "año" used to lose its ñ and fall under the 3-letter cutoff,
      # leaving the signature of a text made only of such words empty.
      sig = Similarity.calculate_signature("año año año")
      sig.should_not eq(Similarity.calculate_signature("ō ō ō"))
    end
  end
end
