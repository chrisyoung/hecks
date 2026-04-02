require "spec_helper"
require "hecks/contract_testing"
require "tmpdir"

RSpec.describe Hecks::ContractTesting::SpecGenerator do
  let(:domain) do
    Hecks.domain "Orders" do
      aggregate "Order" do
        attribute :total, Integer
        attribute :status, String

        command "PlaceOrder" do
          attribute :total, Integer
          attribute :status, String
        end
      end

      aggregate "Item" do
        attribute :name, String

        command "CreateItem" do
          attribute :name, String
        end
      end
    end
  end

  before { @app = Hecks.load(domain) }

  it "generates one spec file per aggregate" do
    Dir.mktmpdir do |dir|
      paths = described_class.new(domain, output_dir: dir).generate
      expect(paths.size).to eq(2)
      basenames = paths.map { |p| File.basename(p) }.sort
      expect(basenames).to eq([
        "item_repository_contract_spec.rb",
        "order_repository_contract_spec.rb"
      ])
    end
  end

  it "uses correct type sample values in generated specs" do
    Dir.mktmpdir do |dir|
      paths = described_class.new(domain, output_dir: dir).generate
      order_spec = File.read(paths.find { |p| p.include?("order") })
      expect(order_spec).to include("total: 1")
      expect(order_spec).to include('status: "test"')
    end
  end

  it "includes the shared examples reference" do
    Dir.mktmpdir do |dir|
      paths = described_class.new(domain, output_dir: dir).generate
      paths.each do |path|
        content = File.read(path)
        expect(content).to include('include_examples "hecks repository contract"')
      end
    end
  end
end
