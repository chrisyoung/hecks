require "spec_helper"

RSpec.describe Hecks::Boot::EventDirectionality do
  def build_domains
    d1 = Hecks.domain "Producer" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end

    d2 = Hecks.domain "Consumer" do
      aggregate "Tracker" do
        attribute :label, String
        command "LogWidget" do
          attribute :label, String
        end
        policy "OnWidgetCreated" do
          on "CreatedWidget"
          trigger "LogWidget"
        end
      end
    end

    d3 = Hecks.domain "Bystander" do
      aggregate "Unrelated" do
        attribute :value, String
        command "DoThing" do
          attribute :value, String
        end
      end
    end

    [d1, d2, d3]
  end

  describe ".build" do
    it "maps listener domains to their event sources" do
      domains = build_domains
      result = described_class.build(domains)

      expect(result["consumer_domain"]).to eq(["producer_domain"])
      expect(result).not_to have_key("producer_domain")
      expect(result).not_to have_key("bystander_domain")
    end
  end

  describe ".validate" do
    it "returns no warnings when declarations match" do
      domains = build_domains
      declarations = { "consumer_domain" => ["producer_domain"] }
      warnings = described_class.validate(domains, declarations)
      expect(warnings).to be_empty
    end

    it "warns when a policy references an undeclared source" do
      domains = build_domains
      declarations = { "consumer_domain" => ["wrong_domain"] }
      warnings = described_class.validate(domains, declarations)
      expect(warnings.size).to eq(1)
      expect(warnings.first).to include("producer_domain")
    end

    it "skips domains without declarations (open mode)" do
      domains = build_domains
      warnings = described_class.validate(domains, {})
      expect(warnings).to be_empty
    end
  end
end
