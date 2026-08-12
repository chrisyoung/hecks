require "spec_helper"
require "tempfile"

# Real coverage for CommandBuilder#given's own real gaps:
#
# 1. A default description -- hecks_nursury (375 files) writes bare
#    `given { predicate }` with no description string; hecksagain used
#    to require one.
# 2. Two named-condition-guard shapes, called with NO block at all:
#    `requires "SoldOut" => false` (Ruby folds the trailing `key =>
#    value` into a single Hash positional, landing in `description`)
#    and `given :field, not_in: :other_field` (`:field` as the first
#    positional, a trailing keyword-shaped hash folded into a SECOND
#    positional). Neither has real predicate semantics yet -- both are
#    recorded as metadata only (folded into the description text),
#    never evaluated. A documented gap, not silently pretended
#    equivalent to a real `given`.
#
# `requires`/`expects` are aliases of `given` landed separately (item
# 1855be0-g's catch-all); this spec exercises the guard shapes through
# `given` itself, which is the real method underneath either name.
#
# `Ports::Extraction.canonical` (the mechanism a real predicate block
# uses to capture its own literal source text) only resolves DURING a
# real bluebook load -- so the real-predicate examples boot an actual
# bluebook rather than driving CommandBuilder standalone. The two
# no-block guard shapes don't touch extraction at all and can be
# tested at the builder level directly.
RSpec.describe "CommandBuilder#given's default description and named-condition guards" do
  def boot(source, hecksagon_name)
    file = Tempfile.new(["command-given-guard-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name) { }
    end
    registry
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  def command_for(source, hecksagon_name, command_name)
    boot(source, hecksagon_name)
      .bluebook(hecksagon_name)
      .aggregate("Thing")
      .command(command_name)
  end

  BARE_GIVEN_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "CommandGivenGuardGrowth" do
      aggregate "Thing" do
        identified_by { id.value }
        value_object "ThingId" do
          attribute :value, String
        end
        attribute :id, ThingId

        command "BareGiven" do
          given { true }
          emits "Done"
        end

        command "DescribedGiven" do
          given("stock remains") { true }
          emits "Done"
        end
      end
    end
  BLUEBOOK

  it "given { predicate } with no description defaults to a generic one" do
    command = command_for(BARE_GIVEN_SOURCE, "CommandGivenGuardGrowth", "BareGiven")

    expect(command.givens.size).to eq(1)
    expect(command.givens.first.description).to eq("a rule holds")
    expect(command.givens.first.canonical).not_to be_empty
  end

  it "an explicit description still wins over the default" do
    command = command_for(BARE_GIVEN_SOURCE, "CommandGivenGuardGrowth", "DescribedGiven")
    expect(command.givens.first.description).to eq("stock remains")
  end

  def build_command(name, &block)
    Hecksagain::Bluebook::DSL::CommandBuilder.build(name, owner: "Thing") do
      instance_eval(&block) if block
      emits "Done"
    end
  end

  it "requires 'X' => false (a Hash positional, no block) is captured as metadata, never evaluated" do
    command = nil
    expect do
      command = build_command("HashGuardGiven") do
        given "SoldOut" => false
      end
    end.not_to raise_error

    expect(command.givens.size).to eq(1)
    guard = command.givens.first
    expect(guard.canonical).to eq("true")
    expect(guard.predicate).to be_nil
    expect(guard.description).to include("SoldOut")
    expect(guard.description).to include("false")
  end

  it "given :field, not_in: :other_field (two positionals, no block) is captured as metadata, never evaluated" do
    command = nil
    expect do
      command = build_command("FieldGuardGiven") do
        given :verb, not_in: :known_verbs
      end
    end.not_to raise_error

    guard = command.givens.first
    expect(guard.canonical).to eq("true")
    expect(guard.predicate).to be_nil
    expect(guard.description).to include("verb")
    expect(guard.description).to include("known_verbs")
  end
end
