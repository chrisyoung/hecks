require "spec_helper"
require "tempfile"

# Real coverage for AggregateBuilder's bare-primitive VO auto-synthesis:
# hecksagain's own named principle is "primitives live in value objects
# only" -- a bare `attribute :x, String` directly on an aggregate is
# refused by the self-hosted meta-validator. This transparently
# auto-synthesises a single-field wrapper value object per bare-primitive
# aggregate attribute, the exact same mechanism `one_of(...)`'s
# `synthesise_closed_set` already uses for inline closed sets.
#
# Also covers the companion collision fix: a synthesised wrapper VO
# named after a bare attribute's own field can collide with a real,
# independently hand-written value_object of the same name declared
# elsewhere in the same aggregate -- resolved by disambiguating the
# SYNTHESISED wrapper only, never the hand-written one.
RSpec.describe "bare-primitive value-object auto-synthesis" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["bare-primitive-vo-growth-", ".bluebook"])
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
      Hecks.hecksagon(hecksagon_name, &binds)
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  describe "a bare primitive attribute on an aggregate" do
    BARE_PRIMITIVE_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "BarePrimitiveGrowth" do
        aggregate "Sensor" do
          identified_by { id.value }

          value_object "SensorId" do
            attribute :value, String
          end

          attribute :id,    SensorId
          attribute :label, String

          command "Install" do
            attribute :id,    SensorId
            attribute :label, String
            emits "Installed"
          end
        end
      end
    BLUEBOOK

    it "auto-wraps into a synthesised single-field value object, no refusal" do
      runtime = boot(BARE_PRIMITIVE_SOURCE, "BarePrimitiveGrowth") do
        ::BarePrimitiveGrowth::Sensor.persisted_by("Memory")
      end

      expect { runtime.dispatch("BarePrimitiveGrowth::Sensor.Install", id: { value: "s1" }, label: { value: "porch" }) }
        .not_to raise_error

      record = runtime.registry.repository("BarePrimitiveGrowth", runtime.registry.bluebook("BarePrimitiveGrowth").aggregate("Sensor")).find("s1")
      expect(record[:label]).to be_a(Hecksagain::Runtime::Value)
      expect(record[:label].to_h).to eq(value: "porch")
    end
  end

  describe "a synthesised wrapper colliding with a hand-written value_object of the same name" do
    COLLISION_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "PrimitiveCollisionGrowth" do
        aggregate "Neuron" do
          identified_by { id.value }

          value_object "NeuronId" do
            attribute :value, String
          end

          value_object "Neurotransmitter" do
            attribute :kind,  String
            attribute :level, Integer
          end

          attribute :id,                NeuronId
          attribute :neurotransmitter,  String
          attribute :embedded,          Neurotransmitter

          command "Fire" do
            attribute :id,               NeuronId
            attribute :neurotransmitter, String
            emits "Fired"
          end
        end
      end
    BLUEBOOK

    it "disambiguates the synthesised wrapper, leaving the hand-written value_object untouched" do
      runtime = boot(COLLISION_SOURCE, "PrimitiveCollisionGrowth") do
        ::PrimitiveCollisionGrowth::Neuron.persisted_by("Memory")
      end

      neuron = runtime.registry.bluebook("PrimitiveCollisionGrowth").aggregate("Neuron")

      # The hand-written value_object keeps its own real name, untouched.
      handwritten = neuron.value_object("Neurotransmitter")
      expect(handwritten.attributes.map(&:name)).to eq(%i[kind level])

      # The bare `attribute :neurotransmitter, String` field is re-pointed at
      # a DISAMBIGUATED synthesised wrapper name, not "Neurotransmitter".
      field = neuron.attributes.find { |a| a.name == :neurotransmitter }
      expect(field.type.to_s).not_to eq("Neurotransmitter")
      expect(field.type.to_s).to eq("NeurotransmitterValue")

      # And a real dispatch proves both concepts actually resolve, not just
      # that the IR happened to build without raising.
      expect do
        runtime.dispatch("PrimitiveCollisionGrowth::Neuron.Fire",
                          id: { value: "n1" }, neurotransmitter: { value: "dopamine" })
      end.not_to raise_error
    end
  end

  describe "the inverted call shape and its kwarg surface (attribute_collector.rb)" do
    INVERTED_ATTRIBUTE_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "InvertedAttributeGrowth" do
        aggregate "Engine" do
          identified_by { id.value }

          value_object "EngineId" do
            attribute :value, String
          end

          value_object "App" do
            attribute :value, String
          end

          attribute :id, EngineId
          attribute App, as: :running_app
          attribute :armed, Boolean

          command "Boot" do
            attribute :id, EngineId
            attribute App, as: :running_app
            attribute :armed, Boolean
            emits "EngineBooted"
          end
        end
      end
    BLUEBOOK

    it "attribute TypeConstant, as: :name resolves the real hand-written type, no wrapper collision" do
      runtime = boot(INVERTED_ATTRIBUTE_SOURCE, "InvertedAttributeGrowth") do
        ::InvertedAttributeGrowth::Engine.persisted_by("Memory")
      end

      engine = runtime.registry.bluebook("InvertedAttributeGrowth").aggregate("Engine")
      field = engine.attributes.find { |a| a.name == :running_app }
      expect(field).not_to be_nil
      expect(field.type.to_s).to eq("App")

      expect do
        runtime.dispatch("InvertedAttributeGrowth::Engine.Boot",
                          id: { value: "e1" }, running_app: { value: "hecksagain" }, armed: true)
      end.not_to raise_error
    end

    it "the Boolean alias resolves to a real true/false field, not a dangling 'Boolean' type name" do
      runtime = boot(INVERTED_ATTRIBUTE_SOURCE, "InvertedAttributeGrowth") do
        ::InvertedAttributeGrowth::Engine.persisted_by("Memory")
      end
      runtime.dispatch("InvertedAttributeGrowth::Engine.Boot",
                        id: { value: "e2" }, running_app: { value: "hecksagain" }, armed: true)

      record = runtime.registry.repository(
        "InvertedAttributeGrowth", runtime.registry.bluebook("InvertedAttributeGrowth").aggregate("Engine")
      ).find("e2")
      expect(record[:armed].to_h).to eq(value: true)
    end
  end

  describe "required: and enum: kwargs (attribute_collector.rb, via ValueObjectBuilder — no aggregate-level primitive wrap in the way)" do
    it "required: false is optional: true's exact inverse alias" do
      vo = Hecksagain::Bluebook::DSL::ValueObjectBuilder.build("RequiredGrowthVo") do
        attribute :nickname, String, required: false
      end

      field = vo.attributes.find { |a| a.name == :nickname }
      expect(field.optional?).to be(true)
    end

    it "enum: is one_of's Rails-style kwarg spelling, synthesising the same closed set one_of would" do
      builder = Hecksagain::Bluebook::DSL::ValueObjectBuilder.new("EnumGrowthVo")
      builder.instance_eval do
        attribute :access, String, enum: %w[permit forbid]
      end

      field = builder.attributes.find { |a| a.name == :access }
      expect(field.type.to_s).to eq("Access")

      closed_set = builder.closed_sets.find { |c| c.hecks_name.to_s == "Access" }
      expect(closed_set).not_to be_nil
      expect(closed_set.members.map { |m| m[:value] }).to eq(%w[permit forbid])
    end
  end
end
