require "spec_helper"

RSpec.describe "Side-Effect-Free Functions (HEC-72)" do
  let(:domain) do
    Hecks.domain "Contacts" do
      aggregate "Person" do
        attribute :first_name, String
        attribute :last_name, String

        function :full_name do
          "#{first_name} #{last_name}"
        end

        value_object "Address" do
          attribute :street, String
          attribute :city, String

          function :one_line do
            "#{street}, #{city}"
          end
        end

        command "CreatePerson" do
          attribute :first_name, String
          attribute :last_name, String
        end
      end
    end
  end

  describe "aggregate functions" do
    it "stores functions on the aggregate IR" do
      agg = domain.aggregates.first
      expect(agg.functions.size).to eq(1)
      expect(agg.functions.first.name).to eq(:full_name)
    end

    it "generates function methods on the aggregate class" do
      Hecks.load(domain)
      person = ContactsDomain::Person.create(first_name: "John", last_name: "Doe")
      expect(person.full_name).to eq("John Doe")
    end
  end

  describe "value object functions" do
    it "stores functions on the value object IR" do
      vo = domain.aggregates.first.value_objects.first
      expect(vo.functions.size).to eq(1)
      expect(vo.functions.first.name).to eq(:one_line)
    end

    it "generates function methods on the value object class" do
      Hecks.load(domain)
      addr = ContactsDomain::Person::Address.new(street: "123 Main", city: "Springfield")
      expect(addr.one_line).to eq("123 Main, Springfield")
    end
  end

  it "serializes functions in DSL round-trip" do
    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).to include("function :full_name")
    expect(source).to include("function :one_line")
  end
end
