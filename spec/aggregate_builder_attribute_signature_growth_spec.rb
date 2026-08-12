require "spec_helper"
require "tempfile"

# Real coverage for AggregateBuilder#attribute's keyword-signature
# regression fix: the primitive-wrapper synthesis pass (item 1855be0-b)
# collapsed its explicit keyword signature into a bare `**kwargs`
# catch-all. That forwards fine at RUNTIME, but ERASES the signature a
# projected parser reads -- spec/syntax_conformance_spec's "declares
# every keyword argument each word's builder takes" inspects
# `instance_method(:attribute).parameters` and only counts real
# `key`/`keyreq` entries, so a `**kwargs` override made every named
# argument syntax.bluebook declares for Aggregate.attribute look
# unanswered from the language's own point of view.
RSpec.describe "AggregateBuilder#attribute's keyword signature" do
  it "names its real keyword arguments -- not a bare **kwargs catch-all" do
    params = Hecksagain::Bluebook::DSL::AggregateBuilder.instance_method(:attribute).parameters
    kinds = params.map(&:first)

    expect(kinds).not_to include(:keyrest), "a **kwargs catch-all erases the signature a projected parser reads"

    named = params.select { |kind, _| %i[key keyreq].include?(kind) }.map(&:last)
    expect(named).to include(:as, :default, :optional, :required, :pattern, :admits, :logged, :enum)
  end

  it "still forwards every keyword through to the real behavior (as:, required:, enum:)" do
    source = <<~BLUEBOOK
      Hecks.bluebook "AttributeSignatureGrowth" do
        aggregate "Widget" do
          identified_by { widget_id.value }

          value_object "WidgetId" do
            attribute :value, String
          end

          attribute :widget_id, WidgetId
          attribute :color, String, enum: %w[red blue], required: true
        end
      end
    BLUEBOOK

    file = Tempfile.new(["attribute-signature-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
    end
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file.close!

    widget = registry.bluebook("AttributeSignatureGrowth").aggregate("Widget")
    color_attribute = widget.attributes.find { |a| a.name == :color }
    expect(color_attribute).not_to be_nil
    expect(color_attribute.optional?).to be(false)
  end
end
