require "spec_helper"

RSpec.describe Hecks::ValidationRules::Naming::IntentionRevealingNames do
  def build_domain(agg_name)
    Hecks.domain("Pizzas") do
      aggregate(agg_name) do
        attribute :name, String
        command("Create#{agg_name}") { attribute :name, String }
      end
    end
  end

  def warnings_for(domain)
    v = Hecks::Validator.new(domain)
    v.valid?
    v.warnings
  end

  describe "generic aggregate names" do
    %w[OrderManager PaymentHandler DataProcessor].each do |name|
      it "warns about '#{name}'" do
        ws = warnings_for(build_domain(name))
        expect(ws.any? { |w| w.include?(name) && w.include?("generic") }).to be true
      end
    end
  end

  describe "clean aggregate names" do
    %w[Pizza Order Payment].each do |name|
      it "does not warn about '#{name}'" do
        ws = warnings_for(build_domain(name))
        expect(ws.select { |w| w.include?("generic") }).to be_empty
      end
    end
  end

  describe "does not produce errors" do
    it "returns no errors for generic names" do
      domain = build_domain("OrderManager")
      v = Hecks::Validator.new(domain)
      valid = v.valid?
      expect(valid).to be true
    end
  end
end
