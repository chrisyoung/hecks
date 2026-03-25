require "spec_helper"
require "tmpdir"
require "sequel"

RSpec.describe "Exploratory: trying to break Hecks" do
  def boot(domain)
    Hecks.load(domain)
  end

  describe "aggregate with minimal attributes" do
    it "creates and finds with only one attribute" do
      domain = Hecks.domain("Minimal") { aggregate("Blank") { attribute :tag, String; command("CreateBlank") { attribute :tag, String } } }
      boot(domain)
      blank = MinimalDomain::Blank.create(tag: "x")
      expect(blank.id).not_to be_nil
      expect(MinimalDomain::Blank.find(blank.id).tag).to eq("x")
    end

    it "validator rejects command with no attributes" do
      domain = Hecks.domain("NoAttr") { aggregate("Blank") { command("CreateBlank") {} } }
      valid, errors = Hecks.validate(domain)
      expect(valid).to be false
      expect(errors.any? { |e| e.include?("no attributes") }).to be true
    end
  end

  describe "aggregate with many attributes" do
    it "handles 20 attributes" do
      domain = Hecks.domain("Big") do
        aggregate "Wide" do
          20.times { |i| attribute :"field_#{i}", String }
          command "CreateWide" do
            20.times { |i| attribute :"field_#{i}", String }
          end
        end
      end
      boot(domain)
      attrs = 20.times.each_with_object({}) { |i, h| h[:"field_#{i}"] = "val_#{i}" }
      wide = BigDomain::Wide.create(**attrs)
      found = BigDomain::Wide.find(wide.id)
      expect(found.field_0).to eq("val_0")
      expect(found.field_19).to eq("val_19")
    end
  end

  describe "special characters in data" do
    it "handles unicode in string attributes" do
      domain = Hecks.domain("Unicode") { aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } } }
      boot(domain)
      thing = UnicodeDomain::Thing.create(name: "Ünïcödé 🍕 日本語")
      found = UnicodeDomain::Thing.find(thing.id)
      expect(found.name).to eq("Ünïcödé 🍕 日本語")
    end

    it "handles very long strings" do
      domain = Hecks.domain("Long") { aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } } }
      boot(domain)
      long_name = "x" * 10_000
      thing = LongDomain::Thing.create(name: long_name)
      expect(LongDomain::Thing.find(thing.id).name.length).to eq(10_000)
    end

    it "handles JSON with special characters" do
      domain = Hecks.domain("JsonSpecial") { aggregate("Thing") { attribute :data, JSON; command("CreateThing") { attribute :data, JSON } } }
      boot(domain)
      data = { "key with spaces" => "value\nwith\nnewlines", "unicode" => "🎉", "quotes" => 'he said "hello"' }
      thing = JsonSpecialDomain::Thing.create(data: data)
      found = JsonSpecialDomain::Thing.find(thing.id)
      expect(found.data["unicode"]).to eq("🎉")
      expect(found.data["quotes"]).to eq('he said "hello"')
    end
  end

  describe "rapid create and delete" do
    it "handles 100 creates" do
      domain = Hecks.domain("Rapid") { aggregate("Item") { attribute :name, String; command("CreateItem") { attribute :name, String } } }
      boot(domain)
      100.times { |i| RapidDomain::Item.create(name: "item_#{i}") }
      expect(RapidDomain::Item.count).to eq(100)
    end

    it "handles create then immediate delete" do
      domain = Hecks.domain("QuickDel") { aggregate("Item") { attribute :name, String; command("CreateItem") { attribute :name, String } } }
      boot(domain)
      item = QuickDelDomain::Item.create(name: "temp")
      QuickDelDomain::Item.delete(item.id)
      expect(QuickDelDomain::Item.count).to eq(0)
      expect(QuickDelDomain::Item.find(item.id)).to be_nil
    end
  end

  describe "query with operators on empty repo" do
    it "gt on empty returns empty" do
      domain = Hecks.domain("EmptyQ") { aggregate("Thing") { attribute :price, Float; command("CreateThing") { attribute :price, Float } } }
      app = boot(domain)
      Hecks::Querying::AdHocQueries.bind(EmptyQDomain::Thing, app["Thing"])
      builder = Hecks::Querying::QueryBuilder.new(app["Thing"])
      results = builder.where(price: builder.gt(10.0))
      expect(results.to_a).to be_empty
      expect(results.count).to eq(0)
    end
  end

  describe "SQL adapter edge cases" do
    let(:domain) do
      Hecks.domain("SqlEdge") do
        aggregate "Item" do
          attribute :name, String
          attribute :price, Float
          attribute :data, JSON
          attribute :tags, list_of("Tag")

          value_object "Tag" do
            attribute :label, String
          end

          command "CreateItem" do
            attribute :name, String
            attribute :price, Float
            attribute :data, JSON
          end
        end
      end
    end

    before do
      Hecks.load(domain)

      domain.aggregates.each do |agg|
        gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: "SqlEdgeDomain")
        eval(gen.generate, TOPLEVEL_BINDING)
      end

      @db = Sequel.sqlite
      @db.create_table(:items) do
        String :id, primary_key: true, size: 36
        String :name; Float :price; String :data, text: true
        String :created_at; String :updated_at
      end
      @db.create_table(:items_tags) do
        String :id, primary_key: true, size: 36
        String :item_id, null: false; String :label
      end

      db = @db
      @app = Hecks.load(domain) do
        adapter "Item", SqlEdgeDomain::Adapters::ItemSqlRepository.new(db)
      end
    end

    it "round-trips nil JSON through SQL" do
      SqlEdgeDomain::Item.create(name: "Test", price: 1.0, data: nil)
      found = SqlEdgeDomain::Item.find(SqlEdgeDomain::Item.first.id)
      expect(found.data).to be_nil
    end

    it "round-trips complex JSON through SQL" do
      SqlEdgeDomain::Item.create(name: "Test", price: 1.0, data: { a: [1, { b: "c" }] })
      found = SqlEdgeDomain::Item.find(SqlEdgeDomain::Item.first.id)
      expect(found.data["a"][1]["b"]).to eq("c")
    end

    it "round-trips nil price through SQL" do
      SqlEdgeDomain::Item.create(name: "Test", price: nil)
      found = SqlEdgeDomain::Item.find(SqlEdgeDomain::Item.first.id)
      expect(found.price).to be_nil
    end

    it "handles update through SQL" do
      item = SqlEdgeDomain::Item.create(name: "Old", price: 5.0)
      updated = item.update(name: "New")
      found = SqlEdgeDomain::Item.find(item.id)
      expect(found.name).to eq("New")
      expect(found.price).to eq(5.0)
    end

    it "delete cascades join table rows" do
      item = SqlEdgeDomain::Item.create(name: "Test", price: 1.0)
      item.tags.create(label: "hot")
      item.tags.create(label: "new")
      expect(@db[:items_tags].count).to eq(2)
      SqlEdgeDomain::Item.delete(item.id)
      expect(@db[:items_tags].count).to eq(0)
    end

    it "query with operators works through SQL" do
      SqlEdgeDomain::Item.create(name: "Cheap", price: 5.0)
      SqlEdgeDomain::Item.create(name: "Mid", price: 15.0)
      SqlEdgeDomain::Item.create(name: "Expensive", price: 50.0)

      repo = @app["Item"]
      results = repo.query(
        conditions: { price: Hecks::Querying::Operators::Gt.new(10.0) },
        order_key: :price, order_direction: :asc, limit: nil, offset: nil
      )
      expect(results.map(&:name)).to eq(["Mid", "Expensive"])
    end
  end

  describe "event sourcing edge cases" do
    it "records events with JSON data" do
      domain = Hecks.domain("EvtSrc") do
        aggregate "Thing" do
          attribute :name, String
          attribute :data, JSON
          command "CreateThing" do
            attribute :name, String
            attribute :data, JSON
          end
        end
      end

      Hecks.load(domain)

      domain.aggregates.each do |agg|
        gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: "EvtSrcDomain")
        eval(gen.generate, TOPLEVEL_BINDING)
      end

      db = Sequel.sqlite
      db.create_table(:things) do
        String :id, primary_key: true, size: 36
        String :name; String :data, text: true
        String :created_at; String :updated_at
      end

      app = Hecks.load(domain) do
        adapter "Thing", EvtSrcDomain::Adapters::ThingSqlRepository.new(db)
      end

      recorder = Hecks::Persistence::EventRecorder.new(db)
      Hecks::Persistence.bind_event_recorder(EvtSrcDomain::Thing, recorder)

      thing = EvtSrcDomain::Thing.create(name: "Test", data: { key: "value" })
      history = EvtSrcDomain::Thing.history(thing.id)
      expect(history.size).to eq(1)
      expect(history.first[:event_type]).to eq("CreatedThing")
      expect(history.first[:data]["name"]).to eq("Test")
    end
  end

  describe "OpenAPI generator edge cases" do
    it "handles domain with no queries" do
      domain = Hecks.domain("NoQuery") { aggregate("Widget") { attribute :name, String; command("CreateWidget") { attribute :name, String } } }
      spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      expect(spec[:paths]).to have_key("/widgets")
      expect(spec[:paths]).to have_key("/events")
    end

    it "handles domain with JSON attributes" do
      domain = Hecks.domain("JsonApi") { aggregate("Widget") { attribute :data, JSON; command("CreateWidget") { attribute :data, JSON } } }
      spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      expect(spec[:components][:schemas]["Widget"][:properties][:data][:type]).to eq("object")
    end

    it "handles multiple aggregates" do
      domain = Hecks.domain("Multi") do
        aggregate("Widget") { attribute :name, String; command("CreateWidget") { attribute :name, String } }
        aggregate("Gadget") { attribute :count, Integer; command("CreateGadget") { attribute :count, Integer } }
      end
      spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      expect(spec[:paths]).to have_key("/widgets")
      expect(spec[:paths]).to have_key("/gadgets")
      expect(spec[:components][:schemas]).to have_key("Widget")
      expect(spec[:components][:schemas]).to have_key("Gadget")
    end
  end

  describe "JSON Schema generator edge cases" do
    it "handles domain with references" do
      domain = Hecks.domain("RefSchema") do
        aggregate("Widget") { attribute :name, String; command("CreateWidget") { attribute :name, String } }
        aggregate("Part") { attribute :widget_id, reference_to("Widget"); command("CreatePart") { attribute :widget_id, reference_to("Widget") } }
      end
      schema = Hecks::HTTP::JsonSchemaGenerator.new(domain).generate
      ref_prop = schema[:definitions]["Part"][:properties][:widget_id]
      expect(ref_prop[:type]).to eq("string")
      expect(ref_prop[:format]).to eq("uuid")
      expect(ref_prop[:description]).to include("Widget")
    end
  end

  describe "DslSerializer round-trip" do
    it "round-trips a complex domain" do
      domain = Hecks.domain "Complex" do
        aggregate "Pizza" do
          attribute :name, String
          attribute :price, Float
          attribute :toppings, list_of("Topping")

          value_object "Topping" do
            attribute :name, String
          end

          validation :name, presence: true

          command "CreatePizza" do
            attribute :name, String
            attribute :price, Float
          end
        end

        aggregate "Order" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer

          command "PlaceOrder" do
            attribute :pizza_id, reference_to("Pizza")
            attribute :quantity, Integer
          end
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      restored = eval(source)
      expect(restored.name).to eq("Complex")
      expect(restored.aggregates.map(&:name)).to eq(["Pizza", "Order"])
      expect(restored.aggregates.first.value_objects.first.name).to eq("Topping")
      expect(restored.aggregates.first.validations.first.field).to eq(:name)
      expect(restored.aggregates.last.attributes.first.reference?).to be true
    end
  end
end
