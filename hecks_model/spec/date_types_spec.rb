require "spec_helper"

RSpec.describe "Date and DateTime attribute types" do
  describe "DSL: attribute :born_on, Date" do
    it "stores Date type on the IR attribute" do
      domain = Hecks.domain("T") do
        aggregate("Person") do
          attribute :name, String
          attribute :born_on, Date
          command("CreatePerson") { attribute :name, String }
        end
      end

      attr = domain.aggregates.first.attributes.find { |a| a.name == :born_on }
      expect(attr.type).to eq(Date)
    end

    it "stores DateTime type on the IR attribute" do
      domain = Hecks.domain("T") do
        aggregate("Event") do
          attribute :title, String
          attribute :starts_at, DateTime
          command("CreateEvent") { attribute :title, String }
        end
      end

      attr = domain.aggregates.first.attributes.find { |a| a.name == :starts_at }
      expect(attr.type).to eq(DateTime)
    end
  end

  describe "AttributeCollector TYPE_MAP" do
    it "resolves :date symbol to Date" do
      domain = Hecks.domain("T") do
        aggregate("A") do
          attribute :d, :date
          command("CreateA") { attribute :d, :date }
        end
      end

      attr = domain.aggregates.first.attributes.find { |a| a.name == :d }
      expect(attr.type).to eq(Date)
    end

    it "resolves :datetime symbol to DateTime" do
      domain = Hecks.domain("T") do
        aggregate("A") do
          attribute :d, :datetime
          command("CreateA") { attribute :d, :datetime }
        end
      end

      attr = domain.aggregates.first.attributes.find { |a| a.name == :d }
      expect(attr.type).to eq(DateTime)
    end
  end

  describe "SqlHelpers type mapping" do
    let(:helpers) do
      Class.new { include Hecks::Migrations::Strategies::SqlHelpers }.new
    end

    it "maps Date to DATE" do
      expect(helpers.sql_type_for(Date)).to eq("DATE")
    end

    it "maps DateTime to VARCHAR(255)" do
      expect(helpers.sql_type_for(DateTime)).to eq("VARCHAR(255)")
    end
  end
end
