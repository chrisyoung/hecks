# Shared between spec/rust_conformance_spec.rb (the fixed, hand-authored
# corpus) and spec/rust_conformance_fuzz_spec.rb (PRD 04 — the same
# differential check, run against SequenceGenerator's own randomly
# generated sequences instead). Factored out so the two never drift on
# what "a known, understood boundary, not a bug" means — that judgment is
# real, cited, and earned per case (see rust_conformance_spec.rb's own
# extensive comments on each), and belongs in exactly one place.
module RustConformanceHelpers
  # Built for THIS fixture/sequence's own domain, every time — never found
  # by trusting whatever happens to already sit at
  # rust/target/{release,debug}/rust. See rust_conformance_spec.rb's own
  # comment on `build_rust_for` for why an ambient binary is unsafe to
  # trust here.
  def build_rust_for(domain_feature, rust_dir)
    cargo_toml = File.read(File.join(rust_dir, "Cargo.toml"))
    return nil unless cargo_toml =~ /^#{Regexp.escape(domain_feature)}\s*=\s*\[\]/

    built = system("cargo", "build", "--no-default-features", "--features", domain_feature,
                   chdir: rust_dir, out: File::NULL, err: File::NULL)
    return nil unless built

    binary = File.join(rust_dir, "target", "debug", "rust")
    File.executable?(binary) ? binary : nil
  end

  # See rust_conformance_spec.rb's own extensive comment on this exact
  # exclusion (a cross-domain policy match Ruby's single-process boot
  # delivers in-process but Rust's kernel genuinely cannot know the
  # outcome of yet) — reproduced verbatim, not re-derived, so both specs
  # agree on what a cross-domain reaction even means.
  def cross_domain_policy_names(rust_output)
    rust_output.fetch("cross_domain_reactions").flatten.to_set { |r| r["policy"] }
  end

  # See rust_conformance_spec.rb's own comment on this exact, narrow,
  # cited gap (an argument-check-ordering difference for one malformed-
  # payload shape three fixed fixtures happen to hit).
  def known_reaction_gap?(reaction)
    reaction["policy"] == "FreezeAccountsOnSuspension" &&
      reaction["trigger"] == "Banking::Account.FreezeAccount" &&
      reaction["delivered"] == false
  end

  # THE FIXED CORPUS'S OWN NARROW LIST — found and named by hand against a
  # small, curated set of fixtures. `Banking::ATMCard.ByFee` used to be
  # here too (a declared query's own `offset`, structurally refused) —
  # removed once Phase 10 (equivalence-gap plan) ported `offset` for real
  # and `bin/project_rust examples/banking` was re-run to pick it up:
  # spec/corpus/rust_conformance/named_queries_order_limit.json now
  # matches byte-for-byte with no tolerance needed for this verb at all
  # (confirmed directly — this fixture failed with exactly this one
  # mismatch before the fix, passed clean after).
  KNOWN_REFUSAL_GAP_VERBS = %w[Banking.ComplianceDashboard].freeze

  def known_refusal_gap?(entry)
    KNOWN_REFUSAL_GAP_VERBS.include?(entry.key?("verb") ? entry["verb"] : entry["query"])
  end

  # THE GENERALIZED FORM — PRD 04's own reason this can't just reuse
  # `known_refusal_gap?`'s fixed list: a RANDOMLY generated sequence can
  # reach any structurally-unsupported query/read-model verb the domain
  # declares, not only the two the fixed, hand-picked corpus happens to
  # exercise (`rust/project/queries.rb`'s and `read_models.rb`'s own
  # documented refusal boundary — offset/cursor/group_by/count/median/
  # cross-reference wheres, the whole Phase 10 backlog). Matched by
  # Rust's own EXACT refusal wording for this boundary
  # (`"is not generated for this domain"` — codegen's own literal string,
  # `rust/project/queries.rb`/`read_models.rb`), never by verb name: a
  # verb-name list would need to grow forever as the fuzzer explores
  # further; this message is the one honest signal codegen itself already
  # emits for "I cannot execute this construct at all," matching
  # rust_conformance_spec.rb's own "a named/declared query step whose
  # shape this generator doesn't cover still refuses cleanly" example
  # verbatim.
  STRUCTURAL_REFUSAL_MARKER = "is not generated for this domain"

  def structural_refusal_gap?(entry)
    (entry["error"] || "").include?(STRUCTURAL_REFUSAL_MARKER)
  end
end
