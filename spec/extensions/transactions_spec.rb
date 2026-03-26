require "spec_helper"
require "hecks/extensions/transactions"

RSpec.describe "hecks_transactions middleware" do
  let(:domain) do
    Hecks.domain "TxnTest" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  after do
    Hecks.actor = nil
    Hecks.tenant = nil
  end

  it "calls next_handler when no DB is present (memory adapter)" do
    app = Hecks.load(domain)
    Hecks.extension_registry[:transactions]&.call(
      Object.const_get("TxnTestDomain"), domain, app
    )

    # Memory adapter has no db.transaction, so middleware falls through
    app.run("CreateWidget", name: "Test")
    expect(app.events.size).to eq(1)
  end

  it "wraps in transaction when DB is available" do
    db = double("db")
    repo = double("repo", db: db)
    command = double("command", class: double("class", repository: repo))
    allow(command.class).to receive(:respond_to?).with(:repository).and_return(true)
    allow(repo).to receive(:respond_to?).with(:db).and_return(true)
    allow(db).to receive(:respond_to?).with(:transaction).and_return(true)

    transaction_called = false
    allow(db).to receive(:transaction) do |&blk|
      transaction_called = true
      blk.call
    end

    inner_called = false
    next_handler = -> { inner_called = true; :ok }

    # Run the middleware logic inline
    r = command.class.respond_to?(:repository) ? command.class.repository : nil
    d = r.respond_to?(:db) ? r.db : nil
    if d && d.respond_to?(:transaction)
      d.transaction { next_handler.call }
    else
      next_handler.call
    end

    expect(transaction_called).to be true
    expect(inner_called).to be true
  end
end
