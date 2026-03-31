require_relative "shared_setup"

RSpec.describe "ActiveHecks::DomainModelCompat" do
  include_context "active_hecks pizzas"
  subject(:pizza) { PizzasDomain::Pizza.new(name: "Margherita") }

  it "#to_model returns self" do
    expect(pizza.to_model).to equal(pizza)
  end

  it "#attributes returns a string-keyed hash" do
    attrs = pizza.attributes
    expect(attrs["name"]).to eq("Margherita")
    expect(attrs).to have_key("id")
  end

  it "#serializable_hash supports :only" do
    hash = pizza.serializable_hash(only: ["name"])
    expect(hash.keys).to eq(["name"])
  end

  it "#serializable_hash supports :except" do
    hash = pizza.serializable_hash(except: ["id"])
    expect(hash).not_to have_key("id")
    expect(hash["name"]).to eq("Margherita")
  end

  it "#as_json returns a JSON-compatible hash" do
    json = pizza.as_json
    expect(json["name"]).to eq("Margherita")
  end

  it "#to_partial_path includes the model name" do
    expect(pizza.to_partial_path).to include("pizza")
  end

  it "#read_attribute_for_serialization delegates to the accessor" do
    expect(pizza.read_attribute_for_serialization(:name)).to eq("Margherita")
  end
end
