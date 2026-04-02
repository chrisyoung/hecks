require "spec_helper"

RSpec.describe "pure functions" do
  describe "DSL parsing" do
    it "parses function keyword on aggregates and builds IR" do
      domain = Hecks.domain("Contacts") do
        aggregate("Person") do
          attribute :first, String
          attribute :last, String
          function :full_name do
            "#{first} #{last}"
          end
          command("CreatePerson") { attribute :first, String; attribute :last, String }
        end
      end

      agg = domain.aggregates.first
      expect(agg.functions.size).to eq(1)

      fn = agg.functions.first
      expect(fn.name).to eq(:full_name)
      expect(fn.block).to be_a(Proc)
    end

    it "parses function keyword on value objects" do
      domain = Hecks.domain("Shipping") do
        aggregate("Shipment") do
          attribute :status, String
          value_object "Address" do
            attribute :street, String
            attribute :city, String
            function :display do
              "#{street}, #{city}"
            end
          end
          command("CreateShipment") { attribute :status, String }
        end
      end

      vo = domain.aggregates.first.value_objects.first
      expect(vo.functions.size).to eq(1)
      expect(vo.functions.first.name).to eq(:display)
    end

    it "supports multiple functions on one aggregate" do
      domain = Hecks.domain("Contacts") do
        aggregate("Person") do
          attribute :first, String
          attribute :last, String
          function(:full_name) { "#{first} #{last}" }
          function(:initials) { "#{first[0]}#{last[0]}" }
          command("CreatePerson") { attribute :first, String }
        end
      end

      expect(domain.aggregates.first.functions.size).to eq(2)
    end
  end

  describe "Ruby code generation" do
    it "generates function methods on aggregate class" do
      domain = Hecks.domain("Contacts") do
        aggregate("Person") do
          attribute :first, String
          attribute :last, String
          function :full_name do
            "#{first} #{last}"
          end
          command("CreatePerson") { attribute :first, String }
        end
      end

      gen = Hecks::Generators::Domain::AggregateGenerator.new(
        domain.aggregates.first, domain_module: "ContactsDomain"
      )
      code = gen.generate

      expect(code).to include("def full_name")
      expect(code).to include("# Pure functions")
    end

    it "generates function methods on value object class" do
      domain = Hecks.domain("Shipping") do
        aggregate("Shipment") do
          attribute :status, String
          value_object "Address" do
            attribute :street, String
            attribute :city, String
            function :display do
              "#{street}, #{city}"
            end
          end
          command("CreateShipment") { attribute :status, String }
        end
      end

      vo = domain.aggregates.first.value_objects.first
      gen = Hecks::Generators::Domain::ValueObjectGenerator.new(
        vo, domain_module: "ShippingDomain", aggregate_name: "Shipment"
      )
      code = gen.generate

      expect(code).to include("def display")
      expect(code).to include("# Pure functions")
    end
  end

  describe "serializer round-trip" do
    it "serializes and restores aggregate functions" do
      domain = Hecks.domain("Contacts") do
        aggregate("Person") do
          attribute :first, String
          function :full_name do
            "#{first} #{last}"
          end
          command("CreatePerson") { attribute :first, String }
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include("function :full_name do")

      restored = eval(source)
      fn = restored.aggregates.first.functions.first
      expect(fn.name).to eq(:full_name)
    end

    it "serializes and restores value object functions" do
      domain = Hecks.domain("Shipping") do
        aggregate("Shipment") do
          attribute :status, String
          value_object "Address" do
            attribute :street, String
            function :display do
              "#{street}, #{city}"
            end
          end
          command("CreateShipment") { attribute :status, String }
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include("function :display do")

      restored = eval(source)
      vo = restored.aggregates.first.value_objects.first
      expect(vo.functions.first.name).to eq(:display)
    end
  end

  describe "validation" do
    it "detects function name collision with regular attribute" do
      domain = Hecks.domain("Contacts") do
        aggregate("Person") do
          attribute :name, String
          function(:name) { "oops" }
          command("CreatePerson") { attribute :name, String }
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      expect(validator.errors).to include(
        "Person: function 'name' collides with an attribute or computed attribute"
      )
    end

    it "detects function name collision with computed attribute" do
      domain = Hecks.domain("Contacts") do
        aggregate("Person") do
          attribute :first, String
          computed(:display) { first }
          function(:display) { first }
          command("CreatePerson") { attribute :first, String }
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      expect(validator.errors).to include(
        "Person: function 'display' collides with an attribute or computed attribute"
      )
    end
  end

  describe "defaults" do
    it "defaults functions to empty array on aggregates" do
      domain = Hecks.domain("Simple") do
        aggregate("Thing") do
          attribute :name, String
          command("CreateThing") { attribute :name, String }
        end
      end

      expect(domain.aggregates.first.functions).to eq([])
    end

    it "defaults functions to empty array on value objects" do
      domain = Hecks.domain("Simple") do
        aggregate("Thing") do
          attribute :name, String
          value_object("Tag") { attribute :label, String }
          command("CreateThing") { attribute :name, String }
        end
      end

      expect(domain.aggregates.first.value_objects.first.functions).to eq([])
    end
  end
end
