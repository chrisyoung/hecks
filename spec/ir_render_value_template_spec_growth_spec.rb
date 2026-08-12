require "spec_helper"

# Real coverage for IR.render_value's missing IR::TemplateSpec spelling:
# `Literal.render` refuses any value it has no pinned spelling for, on
# purpose -- and a raw `IR::TemplateSpec` (`template("fmt %s",
# from_pm(:x))` inside a `with:` value) is exactly such a value, a
# Bluebook::IR-specific Struct, not one of Literal's five primitive/
# collection shapes. `Bluebook.to_h` (called by MetaValidator during
# judging, before the live with_spec is reattached from the pre-judge
# graph -- see BluebookBuilder#reattach_saga_runtime_state!) raised
# instead of rendering.
RSpec.describe "IR.render_value with an IR::TemplateSpec" do
  it "spells a TemplateSpec as its own {format:, args:} Hash instead of raising" do
    spec = Hecksagain::Bluebook::IR::TemplateSpec.new(format: "owner-%s", args: [:owner])

    rendered = Hecksagain::Bluebook::IR.render_value(spec)

    expect(rendered).to eq(Hecksagain::Literal.render(format: "owner-%s", args: [:owner]))
  end

  it "still renders every other value exactly as Literal.render always has" do
    expect(Hecksagain::Bluebook::IR.render_value(:amount)).to eq(":amount")
    expect(Hecksagain::Bluebook::IR.render_value("plain")).to eq('"plain"')
    expect(Hecksagain::Bluebook::IR.render_value(42)).to eq("42")
  end
end
