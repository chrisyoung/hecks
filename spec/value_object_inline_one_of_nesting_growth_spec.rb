require "spec_helper"
require "tempfile"

# Real coverage for a newly-discovered correctness bug in the one_of
# disambiguation fix (item 1855be0-g): `attribute :size, one_of("small",
# "large")` inside a `value_object do ... end` body no longer raises the
# wrong-arity ArgumentError, but the value object it synthesises has
# nowhere to go -- IR::ValueObject.declare has no member for a NESTED
# value object at all (unlike IR::Aggregate, which merges its own
# closed_sets into value_objects). The synthesised shape was silently
# dropped: no crash, no refusal, and the attribute stayed typed as a
# reference to a value object that was never registered --
# `aggregate.value_object("Size")` simply returned nil the first time
# anything looked.
RSpec.describe "ValueObjectBuilder#build refuses an inline one_of it cannot nest" do
  it "refuses with a clear, honest Malformed message instead of silently dropping the shape" do
    expect do
      Hecksagain::Bluebook::DSL::ValueObjectBuilder.build("InlineOneOfNestingGrowth") do
        attribute :size, one_of("small", "large")
      end
    end.to raise_error(
      Hecksagain::Bluebook::DSL::Malformed,
      /InlineOneOfNestingGrowth's attribute "Size" names an inline one_of.*value objects do not nest/
    )
  end

  it "a real aggregate using this shape refuses to load, not silently boots broken" do
    registry = Hecksagain::Runtime::Registry.new
    source = <<~BLUEBOOK
      Hecks.bluebook("InlineOneOfNestingAggregateGrowth") do
        aggregate "Thing" do
          identified_by { thing_id.value }

          value_object "ThingId" do
            attribute :value, String
          end

          attribute :thing_id, ThingId
          attribute :box, Box

          value_object "Box" do
            attribute :size, one_of("small", "large")
          end
        end
      end
    BLUEBOOK

    file = Tempfile.new(["inline-one-of-nesting-aggregate-growth-", ".bluebook"])
    file.write(source)
    file.flush

    expect do
      Hecksagain.with_registry(registry) do
        Kernel.load(InMemoryDomain::EXTRACTION_PORT)
        Kernel.load(InMemoryDomain::PRISM_ADAPTER)
        Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      end
    end.to raise_error(Hecksagain::Bluebook::DSL::Malformed, /value objects do not nest/)
  ensure
    file&.close!
  end

  it "the closed-set-body form (block, no values) still works -- unaffected by this fix" do
    vo = Hecksagain::Bluebook::DSL::ValueObjectBuilder.build("ClosedSetBodyNestingGrowth") do
      one_of do
        member value: "open"
        member value: "shut"
      end
    end

    expect(vo.members.map { |m| m[:value] }).to eq(%w[open shut])
  end
end
