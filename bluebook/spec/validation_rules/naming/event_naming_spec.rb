require "spec_helper"

RSpec.describe Hecks::ValidationRules::Naming::EventNaming do
  def build_domain_with_event(event_name)
    Hecks.domain("Pizzas") do
      aggregate("Pizza") do
        attribute :name, String
        command("CreatePizza") { attribute :name, String }
        event(event_name)
      end
    end
  end

  def warnings_for(domain)
    v = Hecks::Validator.new(domain)
    v.valid?
    v.warnings
  end

  describe "non-past-tense events" do
    %w[BakePizza ApprovingOrder].each do |name|
      it "warns about '#{name}'" do
        ws = warnings_for(build_domain_with_event(name))
        expect(ws.any? { |w| w.include?(name) && w.include?("past tense") }).to be true
      end
    end
  end

  describe "past-tense events" do
    %w[CreatedPizza ApprovedOrder SentNotification PaidInvoice].each do |name|
      it "does not warn about '#{name}'" do
        ws = warnings_for(build_domain_with_event(name))
        expect(ws.select { |w| w.include?("past tense") }).to be_empty
      end
    end
  end

  describe "does not produce errors" do
    it "returns no errors for non-past-tense events" do
      domain = build_domain_with_event("BakePizza")
      v = Hecks::Validator.new(domain)
      valid = v.valid?
      expect(valid).to be true
    end
  end
end
