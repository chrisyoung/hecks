require "spec_helper"

RSpec.describe HecksTemplating::Names do
  describe ".domain_module_name" do
    it "appends Domain" do
      expect(described_class.domain_module_name("Pizzas")).to eq("PizzasDomain")
    end

    it "sanitizes spaces" do
      expect(described_class.domain_module_name("pizza order")).to eq("PizzaOrderDomain")
    end
  end

  describe ".domain_gem_name" do
    it "underscores and appends _domain" do
      expect(described_class.domain_gem_name("Pizzas")).to eq("pizzas_domain")
    end
  end

  describe ".domain_constant_name" do
    it "PascalCases" do
      expect(described_class.domain_constant_name("pizza order")).to eq("PizzaOrder")
    end
  end

  describe ".domain_snake_name" do
    it "underscores" do
      expect(described_class.domain_snake_name("GovernancePolicy")).to eq("governance_policy")
    end
  end

  describe ".domain_aggregate_slug" do
    it "pluralizes" do
      expect(described_class.domain_aggregate_slug("Pizza")).to eq("pizzas")
    end

    it "leaves already-plural names" do
      expect(described_class.domain_aggregate_slug("Addresses")).to eq("addresses")
    end
  end

  describe ".domain_command_name" do
    it "capitalizes verb and appends aggregate" do
      expect(described_class.domain_command_name("create", "Pizza")).to eq("CreatePizza")
    end

    it "handles multi-word verbs" do
      expect(described_class.domain_command_name("add_topping", "Pizza")).to eq("AddTopping")
    end
  end

  describe ".domain_referenced_name" do
    it "strips _id suffix" do
      expect(described_class.domain_referenced_name("post")).to eq("post")
    end
  end

  describe ".domain_command_method" do
    it "strips aggregate suffix from command name" do
      expect(described_class.domain_command_method("CreatePizza", "Pizza")).to eq(:create)
    end

    it "handles multi-word aggregates" do
      expect(described_class.domain_command_method("SuspendGovernancePolicy", "GovernancePolicy")).to eq(:suspend)
    end
  end
end
