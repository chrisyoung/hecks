require "spec_helper"
require "tempfile"

# Real coverage for item 1855be0-g's catch-all cluster: trivial no-op
# stubs (structurally captured so a file boots, never silently
# pretended enforced) PLUS two real, independently-meaningful pieces
# that happened to land in the same commit's tail:
#
# - AggregateBuilder's `identified_by` DEFAULT (first declared
#   attribute's own .value path, for a domain that declares none at
#   all) -- a real behavior change, not a stub.
# - ValueObjectBuilder#one_of's real ArgumentError bug fix (covered in
#   depth by docs/guides/aggregates-and-value-objects.md's own doctest,
#   updated in this same PR) -- exercised here too, directly.
RSpec.describe "1855be0-g catch-all: DSL builder stubs and small real fixes" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["catchall-stubs-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds) if hecksagon_name
    end

    registry.verify! if hecksagon_name
    registry
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  describe "AggregateBuilder#identified_by default (real behavior, not a stub)" do
    NO_IDENTITY_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "NoIdentityCatchallGrowth" do
        aggregate "Widget" do
          value_object "SerialNumber" do
            attribute :value, String
          end

          attribute :serial_number, SerialNumber
          attribute :label, String
        end
      end
    BLUEBOOK

    it "falls back to the FIRST declared attribute's own .value path" do
      registry = boot(NO_IDENTITY_SOURCE, nil)
      widget = registry.bluebook("NoIdentityCatchallGrowth").aggregate("Widget")

      expect(widget.identified_by).to eq(:serial_number)
      expect(widget.identity_paths).to eq(["serial_number.value"])
    end
  end

  describe "AggregateBuilder#fixture (inline, aggregate-level, no-op stub)" do
    it "accepts an inline fixture block with arbitrary field setters, without raising" do
      builder = Hecksagain::Bluebook::DSL::AggregateBuilder.new("FixtureCatchallGrowth")
      expect do
        builder.instance_eval do
          fixture "Default" do
            name "House Battery Bank"
            voltage 12.8
          end
        end
      end.not_to raise_error
    end
  end

  describe "ValueObjectBuilder#description (no-op stub)" do
    it "is accepted, not stored" do
      vo = Hecksagain::Bluebook::DSL::ValueObjectBuilder.build("DescribedVoCatchallGrowth") do
        description "a described value object"
        attribute :value, String
      end
      expect(vo.attributes.map(&:name)).to eq([:value])
    end
  end

  describe "ValueObjectBuilder#one_of's real disambiguation fix" do
    it "the inline shorthand (values, no block) no longer raises the wrong-arity ArgumentError" do
      error = begin
        Hecksagain::Bluebook::DSL::ValueObjectBuilder.build("InlineOneOfCatchallGrowth") do
          attribute :size, one_of("small", "large")
        end
        nil
      rescue StandardError => e
        e
      end

      expect(error).not_to be_a(ArgumentError)
    end

    # GAP CLOSED (item 40, `bfbd513`): the disambiguation fix above no
    # longer raises the wrong-arity ArgumentError, but a value object
    # still cannot HOLD a nested one -- IR::ValueObject has no member for
    # a value object inside a value object. Silently dropping the
    # synthesised closed set left `:size` typed as a reference to a shape
    # that was NEVER REGISTERED anywhere ("field.type.to_s == 'Size'"
    # looked correct while `aggregate.value_object("Size")` returned nil
    # the first time anything looked) -- loads clean, silently broken,
    # worse than the ArgumentError it replaced. Refused honestly now.
    it "still refuses honestly -- a value object cannot hold an inline one_of" do
      expect do
        Hecksagain::Bluebook::DSL::ValueObjectBuilder.build("InlineOneOfNestingCatchallGrowth") do
          attribute :size, one_of("small", "large")
        end
      end.to raise_error(Hecksagain::Bluebook::DSL::Malformed, /value objects do not nest/)
    end

    it "the closed-set-body form (block, no values) still works exactly as before" do
      vo = Hecksagain::Bluebook::DSL::ValueObjectBuilder.build("BodyOneOfCatchallGrowth") do
        one_of do
          member value: "open"
          member value: "shut"
        end
      end

      expect(vo.members.map { |m| m[:value] }).to eq(%w[open shut])
    end
  end

  describe "ValueObjectBuilder#rule (invariant's alias) and invariant's default description" do
    it "rule is invariant's exact alias" do
      source = <<~BLUEBOOK
        Hecks.bluebook "RuleAliasCatchallGrowth" do
          aggregate "AddOn" do
            identified_by { id.value }
            value_object "AddOnId" do
              attribute :value, String
            end
            attribute :id, AddOnId

            value_object "Config" do
              attribute :value, String
              rule("a rule holds") { |vo| true }
            end
            attribute :config, Config
          end
        end
      BLUEBOOK

      registry = boot(source, nil)
      config = registry.bluebook("RuleAliasCatchallGrowth").aggregate("AddOn").value_object("Config")
      expect(config.invariants.map(&:description)).to eq(["a rule holds"])
    end
  end

  describe "HecksagonBuilder#gate (no-op stub)" do
    it "accepts a gate block with allow calls, without raising or storing anything" do
      hecksagon = Hecksagain::Bluebook::DSL::HecksagonBuilder.build("GateCatchallGrowth") do
        gate "Aggregate", :role do
          allow :Cmd1, :Cmd2
        end
      end

      expect(hecksagon.binds).to be_empty
    end
  end

  describe "HecksagonBuilder#method_missing (portal/branding catch-all)" do
    it "absorbs unknown app-surface config verbs rather than raising NoMethodError" do
      expect do
        Hecksagain::Bluebook::DSL::HecksagonBuilder.build("PortalCatchallGrowth") do
          capabilities :webapp
          brand_color "#336699"
        end
      end.not_to raise_error
    end

    it "real methods still win over the catch-all" do
      hecksagon = Hecksagain::Bluebook::DSL::HecksagonBuilder.build("PortalRealMethodCatchallGrowth") do
        subscribe "SomeEvent"
      end
      expect(hecksagon.subscriptions).to eq(["SomeEvent"])
    end
  end

  describe "BluebookBuilder's bare stub surface (glossary/entrypoint/fixture/section/define/lifecycle/event/actor)" do
    it "every stub is accepted so a real file using all of them boots without raising" do
      registry = nil
      expect do
        registry = Hecksagain::Bluebook::DSL::BluebookBuilder.build("BluebookStubsCatchallGrowth") do
          glossary(strict: true)
          entrypoint "Main"
          fixture "Seed", on: "Widget"
          section("Header") { row "key", "value" }
          define "Term", "a definition"
          lifecycle("Named") do
            state "x"
            transition from: "a", to: "b", on: "Event"
          end
          event "SomethingHappened"
          actor "Support", description: "handles tickets"
        end
      end.not_to raise_error

      expect(registry).to be_a(Hecksagain::Bluebook::IR::Bluebook)
    end
  end

  describe "BluebookBuilder#aggregate's inline_description sugar" do
    INLINE_DESCRIPTION_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "InlineDescriptionCatchallGrowth" do
        aggregate "Widget", "a small useful thing" do
          identified_by { id.value }
          value_object "WidgetId" do
            attribute :value, String
          end
          attribute :id, WidgetId
        end
      end
    BLUEBOOK

    it "aggregate \"Name\", \"desc\" do ... end sets the description without a separate call" do
      registry = boot(INLINE_DESCRIPTION_SOURCE, nil)
      expect(registry.bluebook("InlineDescriptionCatchallGrowth").aggregate("Widget").description)
        .to eq("a small useful thing")
    end
  end
end
