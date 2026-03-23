require "spec_helper"
require "tmpdir"

RSpec.describe "Type coercion and type mismatch bugs" do
  def boot(domain)
    tmpdir = Dir.mktmpdir("hecks_type_test")
    gem_path = Hecks.build(domain, output_dir: tmpdir)
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "#{domain.gem_name}.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    Hecks::Services::Application.new(domain)
  end

  # ------------------------------------------------------------------
  # 1. Pass an Integer where String is expected
  # ------------------------------------------------------------------
  describe "Integer where String is expected" do
    let(:domain) do
      Hecks.domain("IntStr") do
        aggregate "Thing" do
          attribute :name, String
          command "CreateThing" do
            attribute :name, String
          end
        end
      end
    end

    before { boot(domain) }

    it "silently accepts an Integer for a String attribute (no coercion)" do
      # BUG PROBE: Hecks should either coerce 42 to "42" or raise a TypeError.
      # Instead it stores the raw Integer.
      thing = IntStrDomain::Thing.create(name: 42)
      expect(thing.name).to eq(42)           # stored as Integer, not String
      expect(thing.name).not_to be_a(String) # confirms no coercion happened
    end

    it "stores a Symbol for a String attribute without coercion" do
      thing = IntStrDomain::Thing.create(name: :hello)
      expect(thing.name).to eq(:hello)
      expect(thing.name).not_to be_a(String)
    end
  end

  # ------------------------------------------------------------------
  # 2. Pass a String where Float is expected
  # ------------------------------------------------------------------
  describe "String where Float is expected" do
    let(:domain) do
      Hecks.domain("StrFloat") do
        aggregate "Priced" do
          attribute :cost, Float
          command "CreatePriced" do
            attribute :cost, Float
          end
        end
      end
    end

    before { boot(domain) }

    it "silently accepts a String for a Float attribute" do
      priced = StrFloatDomain::Priced.create(cost: "not_a_number")
      expect(priced.cost).to eq("not_a_number")
      expect(priced.cost).not_to be_a(Float)
    end

    it "silently accepts a String that looks like a number for Float" do
      priced = StrFloatDomain::Priced.create(cost: "19.99")
      expect(priced.cost).to eq("19.99")
      expect(priced.cost).to be_a(String)  # not coerced to 19.99
    end
  end

  # ------------------------------------------------------------------
  # 3. Pass a Hash where JSON is expected (should work)
  # ------------------------------------------------------------------
  describe "Hash where JSON is expected" do
    let(:domain) do
      Hecks.domain("HashJson") do
        aggregate "Config" do
          attribute :settings, JSON
          command "CreateConfig" do
            attribute :settings, JSON
          end
        end
      end
    end

    before { boot(domain) }

    it "accepts a Hash for a JSON attribute" do
      config = HashJsonDomain::Config.create(settings: { theme: "dark", count: 5 })
      expect(config.settings).to be_a(Hash)
      expect(config.settings[:theme]).to eq("dark")
    end

    it "accepts an Array for a JSON attribute" do
      config = HashJsonDomain::Config.create(settings: [1, 2, 3])
      expect(config.settings).to eq([1, 2, 3])
    end
  end

  # ------------------------------------------------------------------
  # 4. Pass a Proc where JSON is expected (should fail gracefully)
  # ------------------------------------------------------------------
  describe "Proc where JSON is expected" do
    let(:domain) do
      Hecks.domain("ProcJson") do
        aggregate "Config" do
          attribute :settings, JSON
          command "CreateConfig" do
            attribute :settings, JSON
          end
        end
      end
    end

    before { boot(domain) }

    it "silently accepts a Proc for a JSON attribute (not serializable)" do
      # BUG PROBE: A Proc cannot be serialized to JSON. Hecks should reject this
      # but instead stores it silently. This will blow up on any real adapter.
      my_proc = proc { "boom" }
      config = ProcJsonDomain::Config.create(settings: my_proc)
      expect(config.settings).to be_a(Proc)  # stored a Proc where JSON expected
    end

    it "silently accepts a lambda for a JSON attribute" do
      config = ProcJsonDomain::Config.create(settings: -> { 1 + 1 })
      expect(config.settings).to be_a(Proc)
    end

    it "silently accepts an IO object for a JSON attribute" do
      # Another non-serializable type
      config = ProcJsonDomain::Config.create(settings: $stdout)
      expect(config.settings).to be_a(IO)
    end
  end

  # ------------------------------------------------------------------
  # 5. Negative numbers, zero, Infinity, NaN for Float
  # ------------------------------------------------------------------
  describe "Float edge values" do
    let(:domain) do
      Hecks.domain("FloatEdge") do
        aggregate "Measure" do
          attribute :value, Float
          command "CreateMeasure" do
            attribute :value, Float
          end
        end
      end
    end

    before { boot(domain) }

    it "accepts negative float" do
      m = FloatEdgeDomain::Measure.create(value: -42.5)
      expect(m.value).to eq(-42.5)
    end

    it "accepts zero" do
      m = FloatEdgeDomain::Measure.create(value: 0.0)
      expect(m.value).to eq(0.0)
    end

    it "silently accepts Float::INFINITY" do
      # BUG PROBE: Infinity is not valid JSON. Should Hecks reject it?
      m = FloatEdgeDomain::Measure.create(value: Float::INFINITY)
      expect(m.value).to eq(Float::INFINITY)
      expect(m.value.infinite?).to eq(1)
    end

    it "silently accepts negative Infinity" do
      m = FloatEdgeDomain::Measure.create(value: -Float::INFINITY)
      expect(m.value).to eq(-Float::INFINITY)
    end

    it "silently accepts NaN" do
      # BUG PROBE: NaN is problematic -- NaN != NaN, breaks equality checks.
      m = FloatEdgeDomain::Measure.create(value: Float::NAN)
      expect(m.value.nan?).to be true
      # NaN breaks aggregate equality by identity assumption:
      found = FloatEdgeDomain::Measure.find(m.id)
      expect(found.value.nan?).to be true
    end
  end

  # ------------------------------------------------------------------
  # 6. Very large integers
  # ------------------------------------------------------------------
  describe "Very large integers" do
    let(:domain) do
      Hecks.domain("BigInt") do
        aggregate "Counter" do
          attribute :tally, Integer
          command "CreateCounter" do
            attribute :tally, Integer
          end
        end
      end
    end

    before { boot(domain) }

    it "accepts a very large integer (Bignum)" do
      big = 10**100  # googol
      counter = BigIntDomain::Counter.create(tally: big)
      expect(counter.tally).to eq(big)
    end

    it "accepts a very large negative integer" do
      big = -(10**100)
      counter = BigIntDomain::Counter.create(tally: big)
      expect(counter.tally).to eq(big)
    end

    it "silently accepts a Float for an Integer attribute (no coercion)" do
      # BUG PROBE: 3.14 is not an Integer but gets stored as-is.
      counter = BigIntDomain::Counter.create(tally: 3.14)
      expect(counter.tally).to eq(3.14)
      expect(counter.tally).to be_a(Float)
    end
  end

  # ------------------------------------------------------------------
  # 7. Create with wrong number of attributes
  # ------------------------------------------------------------------
  describe "Wrong number of attributes" do
    let(:domain) do
      Hecks.domain("WrongAttrs") do
        aggregate "Widget" do
          attribute :name, String
          attribute :size, Integer
          command "CreateWidget" do
            attribute :name, String
            attribute :size, Integer
          end
        end
      end
    end

    before { boot(domain) }

    it "creates with zero attributes (all default to nil)" do
      widget = WrongAttrsDomain::Widget.create
      expect(widget.name).to be_nil
      expect(widget.size).to be_nil
      expect(widget.id).not_to be_nil  # ID is auto-generated
    end

    it "creates with only one of two attributes" do
      widget = WrongAttrsDomain::Widget.create(name: "partial")
      expect(widget.name).to eq("partial")
      expect(widget.size).to be_nil
    end
  end

  # ------------------------------------------------------------------
  # 8. Create with extra attributes not in the schema
  # ------------------------------------------------------------------
  describe "Extra attributes not in schema" do
    let(:domain) do
      Hecks.domain("ExtraAttrs") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
    end

    before { boot(domain) }

    it "raises ArgumentError on extra attributes (good: rejects unknown keys)" do
      # PASS: Hecks correctly rejects unknown attributes via the generated
      # command class constructor. This is desirable behavior.
      expect {
        ExtraAttrsDomain::Widget.create(name: "valid", color: "red", weight: 99)
      }.to raise_error(ArgumentError, /unknown keyword/)
    end

    it "raises on a single extra attribute" do
      expect {
        ExtraAttrsDomain::Widget.create(name: "test", bogus: true)
      }.to raise_error(ArgumentError, /unknown keyword/)
    end
  end

  # ------------------------------------------------------------------
  # Bonus: Mixed-type chaos
  # ------------------------------------------------------------------
  describe "Mixed-type chaos" do
    let(:domain) do
      Hecks.domain("Chaos") do
        aggregate "Record" do
          attribute :name, String
          attribute :count, Integer
          attribute :price, Float
          attribute :meta, JSON
          command "CreateRecord" do
            attribute :name, String
            attribute :count, Integer
            attribute :price, Float
            attribute :meta, JSON
          end
        end
      end
    end

    before { boot(domain) }

    it "stores every attribute as the wrong type without complaint" do
      # BUG PROBE: Complete type inversion -- every attribute gets a mismatched type.
      record = ChaosDomain::Record.create(
        name: 999,              # Integer where String expected
        count: "forty-two",     # String where Integer expected
        price: [1, 2, 3],       # Array where Float expected
        meta: Time.now          # Time where JSON expected
      )
      expect(record.name).to eq(999)
      expect(record.count).to eq("forty-two")
      expect(record.price).to eq([1, 2, 3])
      expect(record.meta).to be_a(Time)
    end

    it "update also accepts wrong types without complaint" do
      record = ChaosDomain::Record.create(name: "valid", count: 1, price: 1.0, meta: {})
      updated = record.update(name: false, count: nil, price: "free", meta: Object.new)
      expect(updated.name).to eq(false)
      expect(updated.count).to be_nil
      expect(updated.price).to eq("free")
      expect(updated.meta).to be_a(Object)
    end
  end
end
