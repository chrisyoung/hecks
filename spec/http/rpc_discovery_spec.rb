require "spec_helper"

RSpec.describe Hecks::HTTP::RpcDiscovery do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
        query "Classics" do
          where(style: "Classic")
        end
      end
    end
  end

  let(:discovery) { described_class.new(domain).generate }

  it "includes domain name" do
    expect(discovery[:name]).to eq("Pizzas RPC")
  end

  it "includes command methods" do
    names = discovery[:methods].map { |m| m[:name] }
    expect(names).to include("CreatePizza")
  end

  it "includes query methods" do
    names = discovery[:methods].map { |m| m[:name] }
    expect(names).to include("Pizza.classics")
  end

  it "includes CRUD methods" do
    names = discovery[:methods].map { |m| m[:name] }
    expect(names).to include("Pizza.find", "Pizza.all", "Pizza.count", "Pizza.delete")
  end

  it "includes parameter types" do
    create = discovery[:methods].find { |m| m[:name] == "CreatePizza" }
    expect(create[:params].first[:name]).to eq("name")
    expect(create[:params].first[:type]).to eq("String")
  end
end
