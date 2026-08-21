require "spec_helper"

# Holds Hecksagain::Bluebook::PatternSubset::REASONS/::CONSTRUCTS to the
# same "regenerating produces no diff" discipline every other bin/project_*
# generator's own spec already holds its target to (binding_shape_spec.rb,
# primal_ir_shape_spec.rb, parser_table_spec.rb) — this one closes a real,
# found gap: rust/parser/src/build/pattern_subset/reasons.rs used to be a
# hand-copied verbatim mirror of these two Ruby hashes, a real drift risk
# nothing caught until this generator existed.
RSpec.describe "rust/parser/src/build/pattern_subset/reasons.rs" do
  it "regenerating produces no diff — the generator is deterministic and current" do
    root = InMemoryDomain::ROOT
    target = File.join(root, "rust/parser/src/build/pattern_subset/reasons.rs")
    before = File.read(target)

    system(File.join(root, "bin/project_pattern_subset"), out: File::NULL, exception: true)

    expect(File.read(target)).to eq(before)
  end

  it "names every REASONS key CONSTRUCTS also names, and no others" do
    reasons_keys = Hecksagain::Bluebook::PatternSubset::REASONS.keys
    constructs_keys = Hecksagain::Bluebook::PatternSubset::CONSTRUCTS.keys

    expect(reasons_keys).to match_array(constructs_keys)
  end
end
