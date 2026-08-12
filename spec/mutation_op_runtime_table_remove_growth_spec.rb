require "spec_helper"

# Real coverage for CommandRules::Arithmetic::MUTATION_OPS's missing
# "remove" entry: the live table the runtime computes signs from never
# got a `remove` entry when the list-removal mutation op was added --
# only vocabulary.bluebook's own declared MutationOp closed set had it.
# remove's own `when :remove` branch in MutationApplier never calls
# #sign_of, so this was a declared-vocabulary gap invisible to any real
# dispatch, not a behaviour bug -- but it left
# spec/vocabulary_conformance_spec's own "MutationOp declares the same
# sign CommandRules::MUTATION_OPS computes with" test failing, a real,
# already-catalogued gap this closes.
RSpec.describe "CommandRules::Arithmetic::MUTATION_OPS" do
  it "declares remove alongside every other MutationOp the language admits" do
    names = Hecksagain::Runtime::CommandRules::MUTATION_OPS.map(&:name)
    expect(names).to include("remove")
  end

  it "remove carries no sign, matching set/append (no add-or-subtract arithmetic)" do
    remove = Hecksagain::Runtime::CommandRules::MUTATION_OPS.find { |op| op.name == "remove" }
    expect(remove.sign).to be_nil
  end

  it "matches vocabulary.bluebook's own declared MutationOp closed set exactly" do
    live = Hecksagain::Runtime::CommandRules::MUTATION_OPS.map(&:name)

    judged_meta = Hecksagain::Bluebook::MetaValidator.grammar_registry.bluebook("Bluebook")
    aggregate = judged_meta.aggregates.find { |a| a.name == "Vocabulary" }
    declared_names = aggregate.value_objects.find { |vo| vo.hecks_name == "MutationOp" }
                              .members.map { |row| row.to_h[:name] }

    expect(live).to match_array(declared_names)
  end
end
