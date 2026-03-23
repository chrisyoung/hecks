require "spec_helper"

RSpec.describe Hecks::HTTP::OpenapiGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :price, Float
        attribute :points, JSON

        command "CreatePizza" do
          attribute :name, String
          attribute :price, Float
        end

        query "ByStyle" do |style|
          where(style: style)
        end
      end
    end
  end

  let(:spec) { described_class.new(domain).generate }

  it "generates OpenAPI 3.0" do
    expect(spec[:openapi]).to eq("3.0.0")
  end

  it "includes domain name in title" do
    expect(spec[:info][:title]).to eq("Pizzas API")
  end

  it "generates CRUD paths" do
    expect(spec[:paths]).to have_key("/pizzas")
    expect(spec[:paths]).to have_key("/pizzas/{id}")
  end

  it "generates query paths with parameters" do
    expect(spec[:paths]).to have_key("/pizzas/by_style")
    params = spec[:paths]["/pizzas/by_style"][:get][:parameters]
    expect(params.first[:name]).to eq("style")
  end

  it "generates component schemas" do
    expect(spec[:components][:schemas]).to have_key("Pizza")
    expect(spec[:components][:schemas]["Pizza"][:properties][:points][:type]).to eq("object")
  end

  it "includes events path" do
    expect(spec[:paths]).to have_key("/events")
  end
end
