require "spec_helper"
require "tmpdir"
require "fileutils"

# Regression coverage for four already-fixed findings from
# docs/hecks-migration-findings.md — each of these broke silently or
# crashed on real dispatch before its fix landed, and none of them had a
# spec pinning the fix in place. This file is COVERAGE, not implementation.
RSpec.describe "runtime regressions the hecks migration found" do
  def build_runtime
    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      yield
    end
    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
  end

  # Finding #23/24 — `MutationApplier`'s increment/decrement/multiply used to
  # wrap the literal `amount` whenever the target attribute existed, without
  # checking whether the field's own CURRENT value was already wrapped. A
  # VO-typed numeric field with no field-level `default:` leaves `current`
  # genuinely raw (nil, defaulted to 0 by CommandRules::Arithmetic) on its
  # FIRST-ever mutation — so the old code wrapped `amount` but not `current`,
  # and `Arithmetic#arithmetic`'s plain-Numeric path rejected the mismatched
  # pair as a TYPE MISMATCH the caller never made.
  describe "MutationApplier increment Value-wrap symmetry (finding #23/24)" do
    def counter_runtime
      build_runtime do
        Hecks.bluebook("Countotron") do
          aggregate("Counter") do
            identified_by { id.value }
            # NO default: on :balance — the exact shape that crashed. A
            # VO-typed numeric field left genuinely absent until its first
            # mutation, not defaulted at declaration.
            attribute :balance, Amount

            value_object("Amount") { attribute :value, Integer }

            command("Register") do
              emits "Registered"
            end

            command("Bump") do
              reference_to Counter
              # A PLAIN Integer command argument, not itself VO-typed — the
              # shape that reaches MutationApplier still raw, the same way a
              # literal or a plain-typed argument does in real corpus content.
              attribute :amount, Integer
              then_set :balance, increment: :amount
              emits "Bumped"
            end
          end
        end
        Hecks.hecksagon("Countotron") { Countotron::Counter.persisted_by("Memory") }
      end
    end

    it "wraps correctly on the FIRST-ever mutation of a no-default VO-typed numeric field" do
      runtime = counter_runtime
      runtime.dispatch("Countotron::Counter.Register", id: "c1")

      result = runtime.dispatch("Countotron::Counter.Bump", id: "c1", amount: 5)

      expect(result.instance.state[:balance]).to be_a(Hecksagain::Runtime::Value)
      expect(result.instance.state[:balance][:value]).to eq(5)
    end

    it "still increments correctly once the field is already wrapped (second mutation)" do
      runtime = counter_runtime
      runtime.dispatch("Countotron::Counter.Register", id: "c1")
      runtime.dispatch("Countotron::Counter.Bump", id: "c1", amount: 5)

      result = runtime.dispatch("Countotron::Counter.Bump", id: "c1", amount: 3)

      expect(result.instance.state[:balance]).to be_a(Hecksagain::Runtime::Value)
      expect(result.instance.state[:balance][:value]).to eq(8)
    end
  end

  # Finding #25 — `Value::Coercion#from_identifier` never coerced the
  # derived identity string back to a numeric field's declared type, so an
  # aggregate with an Integer- or Float-typed `identified_by` field could
  # never successfully create a record, on any input, valid or not:
  # `Instance#materialize_identity!` seeds the identity field from the
  # derived id STRING on every hydration, and `Value.build`'s own
  # `check_numeric_fields` then refused that internal seed as a type
  # mismatch the caller never made.
  describe "Value::Coercion#from_identifier numeric-identity coercion (finding #25)" do
    def numera_runtime
      build_runtime do
        Hecks.bluebook("Numera") do
          aggregate("Widget") do
            identified_by { serial.value }
            attribute :serial, Serial
            attribute :label,  Label

            value_object("Serial") { attribute :value, Integer }
            value_object("Label")  { attribute :value, String }

            command("Register") do
              attribute :serial, Serial
              attribute :label,  Label
              emits "Registered"
            end

            command("Relabel") do
              reference_to Widget
              attribute :label, Label
              then_set :label, to: :label
              emits "Relabeled"
            end
          end
        end
        Hecks.hecksagon("Numera") { Numera::Widget.persisted_by("Memory") }
      end
    end

    it "creates a record whose identified_by field is Integer-typed" do
      runtime = numera_runtime

      result = runtime.dispatch("Numera::Widget.Register", serial: { value: 42 }, label: { value: "A" })

      expect(result.instance.id).to eq("42")
      expect(result.instance.state[:serial]).to be_a(Hecksagain::Runtime::Value)
      expect(result.instance.state[:serial][:value]).to eq(42)
    end

    it "finds and mutates the EXISTING record by its numeric natural key, not a fresh phantom" do
      runtime = numera_runtime
      runtime.dispatch("Numera::Widget.Register", serial: { value: 42 }, label: { value: "A" })

      # AN ID IS ALWAYS A SCALAR — the bare Integer, not `{ value: 42 }`,
      # is what a self-ref dispatch passes for a natural key.
      result = runtime.dispatch("Numera::Widget.Relabel", serial: 42, label: { value: "B" })

      expect(result.instance.id).to eq("42")
      expect(result.instance.state[:label][:value]).to eq("B")
      expect(result.instance.state[:serial][:value]).to eq(42)
    end

    it "still refuses a genuinely malformed identity with a type mismatch" do
      runtime = numera_runtime
      widget = runtime.registry.bluebook("Numera").aggregate("Widget")
      serial_attribute = widget.attribute(:serial)

      expect { Hecksagain::Runtime::Value.from_identifier(widget, serial_attribute, "not-a-number") }
        .to raise_error(Hecksagain::Runtime::TypeMismatch)
    end
  end

  # Finding #16 — `WorldBuilder` had no `ConstShim` resolver at all, unlike
  # `HecksagonBuilder`/`BluebookBuilder`. The aggregate-qualified
  # binding-mirror form (`Pizzas::Order.charged_by("Stripe") do ... end`)
  # raised `NameError: uninitialized constant Pizzas` on every world file
  # written that way, including the shape the canonical Pizzas example's
  # own `.world` file uses.
  describe "WorldBuilder's ConstShim resolver for the aggregate-qualified form (finding #16)" do
    # A UNIQUE domain/aggregate name, not the literal "Pizzas::Order" the
    # finding itself names — the full suite also boots the real canonical
    # Pizzas example WITH its facade installed (dsl_spec.rb, pizzas_spec.rb),
    # which permanently overwrites the top-level `Pizzas::Order` constant
    # with a real module that has no `charged_by` method. `ConstShim`'s
    # resolver is name-agnostic — any two-level, undeclared constant path
    # exercises the identical fix — so a fictitious name proves the same
    # thing without racing every other spec file's own use of the real one.
    #
    # `fixture_basename` is a LOCAL, not a top-level constant — two spec
    # files each declaring their own `FIXTURE_BASENAME` collide on the same
    # global constant (load_hygiene_spec.rb's own rule), which
    # deploy_bluebook_spec.rb's identically-named constant already claims.
    def boot_with_world(world_body)
      fixture_basename = "runtime_regression_growth_world_fixture"

      Dir.mktmpdir do |dir|
        domain_dir  = File.join(dir, fixture_basename)
        bluebook_dir = File.join(domain_dir, "bluebook")
        FileUtils.mkdir_p(bluebook_dir)

        File.write(File.join(bluebook_dir, "#{fixture_basename}.bluebook"), <<~BLUEBOOK)
          Hecks.bluebook "Growthworld" do
            aggregate "Order" do
              identified_by { name.value }
              attribute :name, OrderName
              value_object "OrderName" do
                attribute :value, String
              end
            end
          end
        BLUEBOOK

        File.write(File.join(bluebook_dir, "#{fixture_basename}.world"), world_body)

        # `install_facade: false` — this suite reuses the same process
        # across every spec file, so a real facade install here would leak
        # a top-level `Growthworld::Order` constant into every other example
        # that runs afterward for no benefit this test needs.
        Hecks.boot(domain_dir, install_facade: false)
      end
    end

    it "boots without NameError for the aggregate-qualified Order.charged_by(\"Stripe\") shape" do
      expect do
        boot_with_world(<<~WORLD)
          Hecks.world "Growthworld" do
            Growthworld::Order.charged_by("Stripe") do
              api_key "sk_test"
            end
          end
        WORLD
      end.not_to raise_error
    end

    it "lands the qualified binding's settings, readable through IR::World#for_binding" do
      runtime = boot_with_world(<<~WORLD)
        Hecks.world "Growthworld" do
          Growthworld::Order.charged_by("Stripe") do
            api_key "sk_test"
          end
        end
      WORLD

      settings = runtime.registry.world("Growthworld").for_binding("charged_by", "Stripe")

      expect(settings).to eq(adapter: "Stripe", api_key: "sk_test")
    end
  end

  # Finding #14 — `role Role, as: Agent` — role-bearer identity synthesis for
  # a cross-domain role assignment. A structural `reference_to` cannot reach
  # a framework-wide concept like Agent from every domain that assigns it a
  # role, so `as:` synthesises a plain, opaque identity field for the bearer
  # instead — never an `IR::Reference`.
  describe "role Type, as: Bearer role-bearer identity synthesis (finding #14)" do
    def role_command
      registry = Hecksagain::Runtime::Registry.new
      Hecksagain.with_registry(registry) do
        Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
        Kernel.load(InMemoryDomain::EXTRACTION_PORT)
        Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
        Kernel.load(InMemoryDomain::PRISM_ADAPTER)
        Hecks.bluebook("RoleDom") do
          aggregate("Thing") do
            identified_by { id.value }

            command("Do") do
              role "Chef", as: Agent
              emits "Done"
            end
          end
        end
      end
      registry.bluebook("RoleDom").aggregate("Thing").command("Do")
    end

    it "keeps the role itself as a plain string" do
      expect(role_command.role).to eq("Chef")
    end

    it "synthesises a plain identity field for the bearer, not a reference_to" do
      command  = role_command
      attribute = command.attributes.find { |a| a.name == :agent }

      expect(attribute).not_to be_nil
      expect(attribute.type).to eq("String")
      expect(attribute.type).not_to be_a(Hecksagain::Bluebook::IR::Reference)
    end
  end
end
