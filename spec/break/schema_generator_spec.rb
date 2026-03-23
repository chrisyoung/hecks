require "spec_helper"
require "json"

# Destructive tests for OpenAPI and JSON Schema generators.
# Goal: expose bugs by feeding unusual domain shapes into the generators.

RSpec.describe "Schema Generator Edge Cases" do
  # ---------------------------------------------------------------------------
  # Helper: build a domain with N trivial aggregates
  # ---------------------------------------------------------------------------
  def domain_with_n_aggregates(n)
    Hecks.domain "Mega" do
      n.times do |i|
        aggregate "Thing#{i}" do
          attribute :name, String
          command "CreateThing#{i}" do
            attribute :name, String
          end
        end
      end
    end
  end

  # ===========================================================================
  # 1. Domain with 10 aggregates -- does the OpenAPI generator emit all paths?
  # ===========================================================================
  describe "OpenAPI with 10 aggregates" do
    let(:domain) { domain_with_n_aggregates(10) }
    let(:spec) { Hecks::HTTP::OpenapiGenerator.new(domain).generate }

    it "generates collection paths for every aggregate" do
      10.times do |i|
        slug = Hecks::Utils.underscore("Thing#{i}") + "s"
        expect(spec[:paths]).to have_key("/#{slug}"),
          "Missing collection path for Thing#{i} (expected /#{slug})"
      end
    end

    it "generates item paths for every aggregate" do
      10.times do |i|
        slug = Hecks::Utils.underscore("Thing#{i}") + "s"
        expect(spec[:paths]).to have_key("/#{slug}/{id}"),
          "Missing item path for Thing#{i}"
      end
    end

    it "generates component schemas for every aggregate" do
      10.times do |i|
        expect(spec[:components][:schemas]).to have_key("Thing#{i}"),
          "Missing schema for Thing#{i}"
      end
    end
  end

  # ===========================================================================
  # 2. Aggregate with NO commands -- does the generator crash or omit POST/PATCH?
  # ===========================================================================
  describe "OpenAPI with commandless aggregate" do
    let(:domain) do
      Hecks.domain "ReadOnly" do
        aggregate "Report" do
          attribute :title, String
          attribute :body, String
        end
      end
    end
    let(:spec) { Hecks::HTTP::OpenapiGenerator.new(domain).generate }

    it "still generates GET collection path" do
      expect(spec[:paths]["/reports"][:get]).not_to be_nil
    end

    it "omits POST when no Create command exists" do
      expect(spec[:paths]["/reports"][:post]).to be_nil
    end

    it "omits PATCH when no Update command exists" do
      expect(spec[:paths]["/reports/{id}"][:patch]).to be_nil
    end

    it "still generates DELETE path" do
      expect(spec[:paths]["/reports/{id}"][:delete]).not_to be_nil
    end

    it "still generates a component schema" do
      expect(spec[:components][:schemas]).to have_key("Report")
    end
  end

  describe "JSON Schema with commandless aggregate" do
    let(:domain) do
      Hecks.domain "ReadOnly" do
        aggregate "Report" do
          attribute :title, String
        end
      end
    end
    let(:schema) { Hecks::HTTP::JsonSchemaGenerator.new(domain).generate }

    it "includes the aggregate definition even with no commands" do
      expect(schema[:definitions]).to have_key("Report")
    end

    it "has no command definitions" do
      cmd_keys = schema[:definitions].keys.select { |k| k.start_with?("Create", "Update", "Delete") }
      expect(cmd_keys).to be_empty
    end

    it "has no event definitions" do
      # Events are inferred from commands, so zero commands = zero events
      evt_keys = schema[:definitions].keys.select { |k| k.start_with?("Created", "Updated", "Deleted") }
      expect(evt_keys).to be_empty
    end
  end

  # ===========================================================================
  # 3. Command with reference_to attribute -- is it typed as uuid in OpenAPI?
  # ===========================================================================
  describe "OpenAPI typing of reference_to attributes" do
    let(:domain) do
      Hecks.domain "Orders" do
        aggregate "Order" do
          attribute :customer_id, reference_to("Customer")
          attribute :quantity, Integer

          command "CreateOrder" do
            attribute :customer_id, reference_to("Customer")
            attribute :quantity, Integer
          end
        end

        aggregate "Customer" do
          attribute :name, String
          command "CreateCustomer" do
            attribute :name, String
          end
        end
      end
    end
    let(:spec) { Hecks::HTTP::OpenapiGenerator.new(domain).generate }

    it "types reference_to as 'string' in component schema (not 'uuid')" do
      # OpenAPI generator uses openapi_type which maps references via ruby_type -> "String" -> "string"
      props = spec[:components][:schemas]["Order"][:properties]
      expect(props[:customer_id][:type]).to eq("string")
    end

    it "BUG? reference_to in request body lacks format:uuid unlike JSON Schema" do
      # The OpenAPI generator's openapi_type doesn't distinguish references from
      # plain strings. JSON Schema generator does (format: "uuid"). This is an
      # inconsistency -- the OpenAPI spec should also mark references as uuid.
      post_props = spec[:paths]["/orders"][:post][:requestBody][:content]["application/json"][:schema][:properties]
      # This WILL pass (proving the bug exists -- no format info):
      expect(post_props[:customer_id]).not_to have_key(:format),
        "If this fails, the bug was fixed! reference_to now has format in OpenAPI."
    end

    it "BUG? non-Create-prefixed commands are invisible to OpenAPI POST generation" do
      # If a command is named "PlaceOrder" instead of "CreateOrder", the OpenAPI
      # generator silently skips it -- no POST path is generated. This means
      # domain-specific command names break the API spec.
      domain2 = Hecks.domain "Orders2" do
        aggregate "Order" do
          attribute :quantity, Integer
          command "PlaceOrder" do
            attribute :quantity, Integer
          end
        end
      end
      spec2 = Hecks::HTTP::OpenapiGenerator.new(domain2).generate
      expect(spec2[:paths]["/orders"][:post]).to be_nil,
        "If this fails, the generator now handles non-Create commands!"
    end
  end

  # ===========================================================================
  # 4. Aggregate with ONLY JSON attributes -- correct types?
  # ===========================================================================
  describe "Aggregate with only JSON attributes" do
    let(:domain) do
      Hecks.domain "Analytics" do
        aggregate "Dashboard" do
          attribute :config, JSON
          attribute :layout, JSON
          attribute :filters, JSON

          command "CreateDashboard" do
            attribute :config, JSON
            attribute :layout, JSON
          end
        end
      end
    end

    it "OpenAPI maps all JSON attrs to 'object'" do
      spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      props = spec[:components][:schemas]["Dashboard"][:properties]
      expect(props[:config][:type]).to eq("object")
      expect(props[:layout][:type]).to eq("object")
      expect(props[:filters][:type]).to eq("object")
    end

    it "JSON Schema maps JSON attrs to ['object', 'array'] (union type)" do
      schema = Hecks::HTTP::JsonSchemaGenerator.new(domain).generate
      props = schema[:definitions]["Dashboard"][:properties]
      expect(props[:config][:type]).to eq(["object", "array"])
      expect(props[:layout][:type]).to eq(["object", "array"])
      expect(props[:filters][:type]).to eq(["object", "array"])
    end

    it "BUG? OpenAPI and JSON Schema disagree on JSON attribute type" do
      # OpenAPI says "object", JSON Schema says ["object","array"].
      # A JSON attribute can hold arrays too, so OpenAPI is arguably wrong.
      openapi_spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      json_schema = Hecks::HTTP::JsonSchemaGenerator.new(domain).generate

      openapi_type = openapi_spec[:components][:schemas]["Dashboard"][:properties][:config][:type]
      jsonschema_type = json_schema[:definitions]["Dashboard"][:properties][:config][:type]

      expect(openapi_type).not_to eq(jsonschema_type),
        "If this fails, the inconsistency was fixed! Both generators now agree."
    end
  end

  # ===========================================================================
  # 5. Query with 3 parameters -- all shown in OpenAPI?
  # ===========================================================================
  describe "Query with multiple parameters" do
    let(:domain) do
      Hecks.domain "Search" do
        aggregate "Product" do
          attribute :name, String
          attribute :category, String
          attribute :price, Float

          command "CreateProduct" do
            attribute :name, String
          end

          query "Advanced" do |category, min_price, max_price|
            where(category: category).where("price >= ?", min_price).where("price <= ?", max_price)
          end
        end
      end
    end

    it "OpenAPI includes all 3 query parameters" do
      spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      params = spec[:paths]["/products/advanced"][:get][:parameters]
      names = params.map { |p| p[:name] }
      expect(names).to contain_exactly("category", "min_price", "max_price")
    end

    it "all query parameters are marked required" do
      spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      params = spec[:paths]["/products/advanced"][:get][:parameters]
      expect(params).to all(include(required: true))
    end

    it "JSON Schema lists all 3 query parameters" do
      schema = Hecks::HTTP::JsonSchemaGenerator.new(domain).generate
      q = schema[:definitions]["Product.advanced"]
      param_names = q[:parameters].map { |p| p[:name] }
      expect(param_names).to contain_exactly("category", "min_price", "max_price")
    end
  end

  # ===========================================================================
  # 6. JSON Schema structural validity -- is the output actually valid?
  # ===========================================================================
  describe "JSON Schema structural validity" do
    let(:domain) do
      Hecks.domain "Full" do
        aggregate "Widget" do
          attribute :name, String
          attribute :weight, Float
          attribute :count, Integer
          attribute :meta, JSON
          attribute :parent_id, reference_to("Widget")
          attribute :parts, list_of("Part")

          value_object "Part" do
            attribute :serial, String
            attribute :quantity, Integer
          end

          command "CreateWidget" do
            attribute :name, String
            attribute :weight, Float
          end

          command "UpdateWidget" do
            attribute :name, String
          end

          query "ByWeight" do |min_weight|
            where("weight >= ?", min_weight)
          end
        end
      end
    end

    let(:schema) { Hecks::HTTP::JsonSchemaGenerator.new(domain).generate }
    let(:json_str) { JSON.pretty_generate(schema) }
    let(:parsed) { JSON.parse(json_str) }

    it "round-trips through JSON.parse without error" do
      expect { parsed }.not_to raise_error
    end

    it "has a $schema key pointing to json-schema.org" do
      expect(parsed["$schema"]).to match(/json-schema\.org/)
    end

    it "every definition has a 'type' or 'description' key" do
      parsed["definitions"].each do |name, defn|
        has_type = defn.key?("type")
        has_desc = defn.key?("description")
        expect(has_type || has_desc).to be(true),
          "Definition '#{name}' has neither 'type' nor 'description'"
      end
    end

    it "every $ref points to an existing definition" do
      refs = json_str.scan(/"\$ref"\s*:\s*"#\/definitions\/([^"]+)"/).flatten
      refs.each do |ref_name|
        expect(parsed["definitions"]).to have_key(ref_name),
          "Dangling $ref: #/definitions/#{ref_name}"
      end
    end

    it "BUG? 'required' arrays use strings but properties use symbols (mixed keys)" do
      # The generator builds properties with symbol keys but required with string keys.
      # After JSON round-trip this is fine, but in raw Ruby the mismatch could cause
      # lookups to fail if someone does schema[:definitions]["Widget"][:required].include?(:id)
      widget = schema[:definitions]["Widget"]
      required = widget[:required]
      prop_keys = widget[:properties].keys

      # required has strings, properties has symbols -- this is a key-type mismatch
      expect(required.first).to be_a(String)
      expect(prop_keys.first).to be_a(Symbol)
    end
  end

  # ===========================================================================
  # 7. OpenAPI completeness -- all HTTP methods for each aggregate
  # ===========================================================================
  describe "OpenAPI HTTP method completeness" do
    let(:domain) do
      Hecks.domain "Complete" do
        aggregate "Item" do
          attribute :name, String

          command "CreateItem" do
            attribute :name, String
          end

          command "UpdateItem" do
            attribute :name, String
          end
        end
      end
    end
    let(:spec) { Hecks::HTTP::OpenapiGenerator.new(domain).generate }

    it "collection path has GET and POST" do
      collection = spec[:paths]["/items"]
      expect(collection).to have_key(:get)
      expect(collection).to have_key(:post)
    end

    it "item path has GET, PATCH, and DELETE" do
      item = spec[:paths]["/items/{id}"]
      expect(item).to have_key(:get)
      expect(item).to have_key(:patch)
      expect(item).to have_key(:delete)
    end

    it "does NOT generate PUT (only PATCH for updates)" do
      item = spec[:paths]["/items/{id}"]
      expect(item).not_to have_key(:put),
        "Unexpected PUT method generated -- Hecks uses PATCH for updates"
    end

    it "events path only has GET" do
      events = spec[:paths]["/events"]
      expect(events).to have_key(:get)
      expect(events.keys).to eq([:get])
    end
  end

  # ===========================================================================
  # 8. OpenAPI with bounded contexts -- does it flatten correctly?
  # ===========================================================================
  describe "OpenAPI with bounded contexts" do
    let(:domain) do
      Hecks.domain "ECommerce" do
        context "Catalog" do
          aggregate "Product" do
            attribute :name, String
            command "CreateProduct" do
              attribute :name, String
            end
          end
        end
        context "Ordering" do
          aggregate "Cart" do
            attribute :total, Float
            command "CreateCart" do
              attribute :total, Float
            end
          end
        end
      end
    end
    let(:spec) { Hecks::HTTP::OpenapiGenerator.new(domain).generate }

    it "generates paths for aggregates from all contexts" do
      expect(spec[:paths]).to have_key("/products")
      expect(spec[:paths]).to have_key("/carts")
    end

    it "generates schemas for aggregates from all contexts" do
      expect(spec[:components][:schemas]).to have_key("Product")
      expect(spec[:components][:schemas]).to have_key("Cart")
    end
  end

  # ===========================================================================
  # 9. Aggregate with list_of but no matching value_object -- dangling $ref?
  # ===========================================================================
  describe "JSON Schema with dangling list_of reference" do
    let(:domain) do
      Hecks.domain "Broken" do
        aggregate "Invoice" do
          attribute :line_items, list_of("LineItem")
          # Deliberately NO value_object "LineItem" defined

          command "CreateInvoice" do
            attribute :amount, Float
          end
        end
      end
    end

    it "BUG? generates list attr without $ref when value object is missing" do
      schema = Hecks::HTTP::JsonSchemaGenerator.new(domain).generate
      items_schema = schema[:definitions]["Invoice"][:properties][:line_items][:items]
      # When the value object is not found, it falls back to { type: "object" }
      # but there's no warning. The $ref is silently omitted.
      expect(items_schema).to eq({ type: "object" }),
        "Expected fallback to {type: 'object'} for missing value object"
    end
  end

  # ===========================================================================
  # 10. Empty domain -- zero aggregates
  # ===========================================================================
  describe "Generators with empty domain (no aggregates)" do
    let(:domain) { Hecks.domain("Empty") {} }

    it "OpenAPI generates valid structure with only /events path" do
      spec = Hecks::HTTP::OpenapiGenerator.new(domain).generate
      expect(spec[:paths].keys).to eq(["/events"])
      expect(spec[:components][:schemas]).to be_empty
    end

    it "JSON Schema generates valid structure with empty definitions" do
      schema = Hecks::HTTP::JsonSchemaGenerator.new(domain).generate
      expect(schema[:definitions]).to be_empty
    end
  end

  # ===========================================================================
  # 11. Aggregate name that needs heavy underscore conversion
  # ===========================================================================
  describe "OpenAPI slug generation for multi-word aggregate names" do
    let(:domain) do
      Hecks.domain "CRM" do
        aggregate "SalesRepresentative" do
          attribute :name, String
          command "CreateSalesRepresentative" do
            attribute :name, String
          end
        end
      end
    end
    let(:spec) { Hecks::HTTP::OpenapiGenerator.new(domain).generate }

    it "correctly underscores multi-word aggregate names in paths" do
      expect(spec[:paths]).to have_key("/sales_representatives")
      expect(spec[:paths]).to have_key("/sales_representatives/{id}")
    end
  end

  # ===========================================================================
  # 12. Command attributes include list_of -- how does OpenAPI handle it?
  # ===========================================================================
  describe "OpenAPI request body with list_of attribute in command" do
    let(:domain) do
      Hecks.domain "Bulk" do
        aggregate "Batch" do
          attribute :name, String

          command "CreateBatch" do
            attribute :name, String
            attribute :items, list_of("Item")
          end
        end
      end
    end
    let(:spec) { Hecks::HTTP::OpenapiGenerator.new(domain).generate }

    it "BUG? list_of in command request body is typed as 'string' not 'array'" do
      # openapi_type checks ruby_type which returns "Array" for list attrs,
      # but the case statement doesn't handle "Array" -- falls through to "string"
      post_props = spec[:paths]["/batchs"][:post][:requestBody][:content]["application/json"][:schema][:properties]
      items_type = post_props[:items][:type]

      # This exposes the bug: list attributes in commands become "string" in OpenAPI
      expect(items_type).to eq("string"),
        "If this fails with 'array', the bug was fixed! list_of now maps correctly."
    end
  end
end
