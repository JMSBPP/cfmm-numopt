/- TEST-09 negative control for GATE-07. NOT part of the Lake project, never
   imported, never built. It carries REAL `sorry`s inside INDENTED, NAMESPACED
   declarations -- the shape the previous column-0 `^theorem` grep could not see.

   This file is the ONLY artifact that can prove `make lean-sorry-check` fires:
   the lean4-spec submodule contains no real `sorry` anywhere (its single
   occurrence of the token, at exp/eta.lean:602, is inside a /- -/ doc comment).
   A sorry-scan of the tree therefore has nothing to find, and a gate that has
   never been observed to go red is not evidence.

   Any repo-wide sorry scan must exclude model/test/_mutants/. -/
namespace SorryFixture

namespace Inner

  theorem indented_namespaced_sorry (n : Nat) : n + 0 = n := by
    sorry

  lemma indented_namespaced_clean (n : Nat) : n + 0 = n := by
    simp

  /- The mis-attribution control: this declaration is CLEAN, and the next one is
     not. The old column-0 awk extractor terminated only on a column-0 construct,
     so it swallowed both and blamed this one for the sorry below. -/
  lemma clean_before_a_later_sorry (n : Nat) : n = n :=
    rfl

  theorem later_sorry (n : Nat) : n + 0 = n := by
    sorry

  /- The comment-stripping control: the token `sorry` appears here in a doc
     comment, exactly as it does at lean4-spec/exp/eta.lean:602, and must NOT
     redden the declaration that follows. -/
  lemma clean_with_sorry_in_its_doc_comment (n : Nat) : n = n :=
    rfl

  lemma clean_with_sorry_in_a_line_comment (n : Nat) : n = n :=
    -- not a sorry, just the word sorry in a line comment
    rfl

end Inner

end SorryFixture
