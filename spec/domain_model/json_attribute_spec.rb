require "spec_helper"
require "tmpdir"
require "sequel"

RSpec.describe "JSON attribute type" do
  let(:domain) do
    Hecks.domain "Geo" do
      aggregate "Road" do
        attribute :name, String
        attribute :points, JSON
        attribute :radii, JSON

        command "CreateRoad" do
          attribute :name, String
          attribute :points, JSON
          attribute :radii, JSON
        end
      end
    end
  end

  before do
    Hecks.load_domain(domain)
  end

  describe "memory adapter" do
    before { @app = Hecks::Services::Application.new(domain) }

    it "stores arrays natively" do
      road = GeoDomain::Road.create(name: "Main", points: [{x: 0, y: 0}, {x: 100, y: 50}], radii: [400])
      expect(road.points).to be_an(Array)
      expect(road.points.first[:x]).to eq(0)
    end
  end

  describe "SQL adapter" do
    before do
      domain.aggregates.each do |agg|
        gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: "GeoDomain")
        eval(gen.generate, TOPLEVEL_BINDING)
      end

      @db = Sequel.sqlite
      @db.create_table(:roads) do
        String :id, primary_key: true, size: 36
        String :name; String :points, text: true; String :radii, text: true
        String :created_at; String :updated_at
      end

      db = @db
      @app = Hecks::Services::Application.new(domain) do
        adapter "Road", GeoDomain::Adapters::RoadSqlRepository.new(db)
      end
    end

    it "serializes to JSON and deserializes back" do
      GeoDomain::Road.create(name: "Oak", points: [{x: 50, y: 50}], radii: [400])
      found = GeoDomain::Road.find(GeoDomain::Road.first.id)
      expect(found.points).to be_an(Array)
      expect(found.points.first["x"]).to eq(50)
    end

    it "stores null for nil JSON attributes" do
      GeoDomain::Road.create(name: "Empty", points: nil, radii: nil)
      found = GeoDomain::Road.find(GeoDomain::Road.first.id)
      expect(found.points).to be_nil
    end
  end

  describe "Attribute model" do
    it "json? returns true for JSON type" do
      attr = Hecks::DomainModel::Structure::Attribute.new(name: :data, type: JSON)
      expect(attr.json?).to be true
      expect(attr.ruby_type).to eq("JSON")
    end

    it "json? returns false for other types" do
      attr = Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)
      expect(attr.json?).to be false
    end
  end
end
