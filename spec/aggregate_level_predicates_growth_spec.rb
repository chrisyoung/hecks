require "spec_helper"
require "tempfile"

# Real coverage for AggregateBuilder's whole-record predicate surface:
#
#   specification :in_lucid_rem do |body| body.state == "sleeping" end
#   invariant "append-only" do |record| record.retracted_at.nil? end
#   rule "..." do ... end          # alias for invariant, at the AGGREGATE level
#   validation :field, presence: true
#
# `specification` (a NAMED, reusable boolean predicate) and `invariant`/
# `rule` (a whole-record rule, mirroring ValueObjectBuilder's own
# field-scoped invariant) are captured structurally so the file boots
# -- NOT yet threaded into IR::Aggregate or walked at dispatch time, a
# real documented gap. `validation` is a deliberate no-op stub: unlike
# invariant/specification, its predicate is not built from real literal
# source text, so canonicalizing it risked a subtly wrong form rather
# than an honest gap.
#
# `Ports::Extraction.canonical` (the mechanism both `specification` and
# `invariant` use to capture their own literal source text) only
# resolves DURING a real bluebook load -- so this spec boots a real
# bluebook rather than driving AggregateBuilder standalone.
RSpec.describe "AggregateBuilder whole-record predicates" do
  def boot(source, hecksagon_name)
    file = Tempfile.new(["aggregate-level-predicates-growth-", ".bluebook"])
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

  def aggregate_builder_for(source, hecksagon_name, aggregate_name)
    captured = nil
    original_build = Hecksagain::Bluebook::DSL::AggregateBuilder.method(:build)
    Hecksagain::Bluebook::DSL::AggregateBuilder.define_singleton_method(:build) do |name, inline = nil, &block|
      builder = new(name)
      builder.description(inline) if inline
      builder.instance_eval(&block) if block
      captured = builder if name == aggregate_name
      builder.build
    end

    boot(source, hecksagon_name)
    captured
  ensure
    Hecksagain::Bluebook::DSL::AggregateBuilder.define_singleton_method(:build, original_build)
  end

  SPEC_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "AggregatePredicatesGrowth" do
      aggregate "Sleeper" do
        identified_by { sleeper_id.value }

        value_object "SleeperId" do
          attribute :value, String
        end

        attribute :sleeper_id, SleeperId
        attribute :state, String

        specification(:in_lucid_rem) { |body| body.state == "sleeping" }
        invariant("append-only — never updated, never deleted") { |record| true }
        rule("a rule holds too") { |record| true }
        validation :state, presence: true

        command "Sleep" do
          attribute :sleeper_id, SleeperId
          emits "SleeperSlept"
        end
      end
    end
  BLUEBOOK

  it "specification captures a named predicate with its own canonical source text" do
    builder = aggregate_builder_for(SPEC_SOURCE, "AggregatePredicatesGrowth", "Sleeper")

    expect(builder.specifications.size).to eq(1)
    spec = builder.specifications.first
    expect(spec[:name]).to eq("in_lucid_rem")
    expect(spec[:canonical]).to be_a(String)
    expect(spec[:canonical]).not_to be_empty
    expect(spec[:predicate]).to be_a(Proc)
  end

  it "invariant captures a whole-record rule, distinct from a value object's field-scoped invariant" do
    builder = aggregate_builder_for(SPEC_SOURCE, "AggregatePredicatesGrowth", "Sleeper")

    # Both `invariant("...")` and its `rule("...")` alias landed here --
    # two entries in the SAME list, one shared method under two names.
    expect(builder.aggregate_invariants.size).to eq(2)
    descriptions = builder.aggregate_invariants.map { |r| r[:description] }
    expect(descriptions).to eq(["append-only — never updated, never deleted", "a rule holds too"])
    expect(builder.aggregate_invariants.first[:canonical]).not_to be_empty
  end

  it "invariant defaults its description when none is given" do
    source = <<~BLUEBOOK
      Hecks.bluebook "AggregatePredicatesDefaultGrowth" do
        aggregate "DefaultDescribed" do
          identified_by { id.value }
          value_object "DefaultDescribedId" do
            attribute :value, String
          end
          attribute :id, DefaultDescribedId

          invariant { |record| true }

          command "Touch" do
            attribute :id, DefaultDescribedId
            emits "Touched"
          end
        end
      end
    BLUEBOOK

    builder = aggregate_builder_for(source, "AggregatePredicatesDefaultGrowth", "DefaultDescribed")
    expect(builder.aggregate_invariants.first[:description]).to eq("an invariant holds")
  end

  it "validation is a documented no-op stub -- the file boots, nothing is stored or enforced" do
    expect { boot(SPEC_SOURCE, "AggregatePredicatesGrowth") }.not_to raise_error
  end

  it "specifications and invariants are NOT yet threaded into IR::Aggregate (documented gap, not silently faked)" do
    registry = boot(SPEC_SOURCE, "AggregatePredicatesGrowth")
    aggregate = registry.bluebook("AggregatePredicatesGrowth").aggregate("Sleeper")

    expect(aggregate).not_to respond_to(:specifications)
    expect(aggregate).not_to respond_to(:aggregate_invariants)
  end
end
