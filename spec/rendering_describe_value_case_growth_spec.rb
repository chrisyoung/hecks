require "spec_helper"

# Real coverage for Rendering#describe's missing Runtime::Value case: a
# Value reaching a refusal message (MutationApplier's own
# increment/decrement/multiply `amount`, an Admissibility `current`, ...)
# had no case here, falling straight through to Ruby's own #inspect and
# leaking a raw object pointer ("#<Hecksagain::Runtime::Value:0x...>")
# into an otherwise-correct domain refusal.
RSpec.describe "Rendering.describe with a Runtime::Value" do
  VALUE_OBJECT_DOUBLE = Struct.new(:hecks_name) do
    def to_h = { name: hecks_name }
  end

  def single_field_value(scalar)
    vo = VALUE_OBJECT_DOUBLE.new("SingleFieldGrowth")
    Hecksagain::Runtime::Value.new(vo, value: scalar)
  end

  def multi_field_value(fields)
    vo = VALUE_OBJECT_DOUBLE.new("MultiFieldGrowth")
    Hecksagain::Runtime::Value.new(vo, fields)
  end

  it "unwraps a single-field value object to its bare scalar, not an object pointer" do
    expect(Hecksagain::Rendering.describe(single_field_value("alive"))).to eq('"alive"')
  end

  it "renders a multi-field value object as its fields' JSON" do
    described = Hecksagain::Rendering.describe(multi_field_value(cents: 500, currency: "USD"))
    expect(described).to eq(JSON.generate(cents: 500, currency: "USD"))
  end

  it "never falls through to Ruby's raw #inspect (no object pointer leaks)" do
    expect(Hecksagain::Rendering.describe(single_field_value(42))).not_to match(/#<Hecksagain::Runtime::Value/)
    expect(Hecksagain::Rendering.describe(multi_field_value(a: 1, b: 2))).not_to match(/#<Hecksagain::Runtime::Value/)
  end

  it "still describes an ordinary scalar the same as before" do
    expect(Hecksagain::Rendering.describe(42)).to eq("42")
    expect(Hecksagain::Rendering.describe("plain")).to eq('"plain"')
  end
end
