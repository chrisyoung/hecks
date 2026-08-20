require "spec_helper"

RSpec.describe "D1 execution-plan capabilities" do
  def item_aggregate
    Hecksagain::Bluebook::DSL::BluebookBuilder.build("D1Planning") do
      vision "D1 implements the same atomic-put contract as Memory and SQLite"

      aggregate "Item" do
        identified_by do
          attribute :sku, String
        end

        value_object("Label") { attribute :value, String }
        attribute :label, Label
      end
    end.aggregate("Item")
  end

  def fake_batch_connection
    Class.new do
      attr_reader :batches

      def initialize
        @batches = []
        @ids = {}
      end

      def execute(*)
        raise "atomic_put must use one batch, not independent execute calls"
      end

      def batch(statements)
        @batches << statements
        id = statements.fetch(0).fetch(1).fetch(0).to_s
        status = @ids.key?(id) ? "replaced" : "inserted"
        @ids[id] = true
        [[{ "status" => status }], [], []]
      end
    end.new
  end

  def adapter_with(connection, aggregate)
    Hecksagain::Adapters::D1.allocate.tap do |adapter|
      adapter.instance_variable_set(:@aggregate, aggregate)
      adapter.instance_variable_set(:@db, connection)
    end
  end

  it "uses one transactional batch and reports the database-classified insert or replacement outcome" do
    aggregate = item_aggregate
    connection = fake_batch_connection
    repository = Hecksagain::Ports::Persistence::AppendOnly.new(adapter_with(connection, aggregate))

    first = Hecksagain::Runtime::Instance.new(
      aggregate: aggregate,
      id:        "sku-1",
      state:     { identity: { sku: "sku-1" }, label: { value: "First" } }
    )
    second = Hecksagain::Runtime::Instance.new(
      aggregate: aggregate,
      id:        "sku-1",
      state:     { identity: { sku: "sku-1" }, label: { value: "Second" } }
    )

    expect(repository.capabilities).to eq([:atomic_put])
    expect(repository.atomic_put(first).status).to eq(:inserted)
    expect(repository.atomic_put(second).status).to eq(:replaced)

    expect(connection.batches.size).to eq(2)
    connection.batches.each do |statements|
      expect(statements.size).to eq(3)
      expect(statements[0][0]).to match(/SELECT CASE WHEN EXISTS .* AS status/)
      expect(statements[1][0]).to include('INSERT INTO "item_entries"')
      expect(statements[2][0]).to include('INSERT OR REPLACE INTO "item"')
    end
  end

  it "encodes the connection batch as one REST request and returns each statement's rows in order" do
    connection = Hecksagain::Adapters::D1::Connection.new(
      account_id:  "account",
      database_id: "database",
      api_token:   "token"
    )
    response = double(
      code: "200",
      body: JSON.generate(
        success: true,
        result:  [
          { success: true, results: [{ status: "inserted" }] },
          { success: true, results: [] }
        ]
      )
    )
    http = double
    payload = nil

    allow(http).to receive(:request) do |request|
      payload = JSON.parse(request.body)
      response
    end
    allow(Net::HTTP).to receive(:start) { |*, &block| block.call(http) }

    rows = connection.batch([
                              ["SELECT ? AS status", ["inserted"]],
                              ["INSERT INTO items (id) VALUES (?)", ["sku-1"]]
                            ])

    expect(payload).to eq(
      "batch" => [
        { "sql" => "SELECT ? AS status", "params" => ["inserted"] },
        { "sql" => "INSERT INTO items (id) VALUES (?)", "params" => ["sku-1"] }
      ]
    )
    expect(rows).to eq([[{ "status" => "inserted" }], []])
  end
end
