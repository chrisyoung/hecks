require "spec_helper"

RSpec.describe "Domain classification" do
  describe "DSL" do
    it "defaults to :supporting when not specified" do
      domain = Hecks.domain("Notifications") do
        aggregate("Email") { attribute :to, String; command("SendEmail") { attribute :to, String } }
      end
      expect(domain.classification).to eq(:supporting)
      expect(domain.supporting?).to be true
      expect(domain.core?).to be false
      expect(domain.generic?).to be false
    end

    it "accepts :core classification" do
      domain = Hecks.domain("Billing") do
        classification :core
        aggregate("Invoice") { attribute :amount, Float; command("CreateInvoice") { attribute :amount, Float } }
      end
      expect(domain.classification).to eq(:core)
      expect(domain.core?).to be true
      expect(domain.supporting?).to be false
    end

    it "accepts :supporting classification" do
      domain = Hecks.domain("Reporting") do
        classification :supporting
        aggregate("Report") { attribute :title, String; command("CreateReport") { attribute :title, String } }
      end
      expect(domain.classification).to eq(:supporting)
      expect(domain.supporting?).to be true
    end

    it "accepts :generic classification" do
      domain = Hecks.domain("Auth") do
        classification :generic
        aggregate("User") { attribute :email, String; command("CreateUser") { attribute :email, String } }
      end
      expect(domain.classification).to eq(:generic)
      expect(domain.generic?).to be true
      expect(domain.core?).to be false
      expect(domain.supporting?).to be false
    end

    it "rejects invalid classification values" do
      expect {
        Hecks.domain("Bad") do
          classification :critical
          aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } }
        end
      }.to raise_error(ArgumentError, /Invalid classification.*critical/)
    end
  end

  describe "serializer" do
    it "emits classification :core in DSL output" do
      domain = Hecks.domain("Billing") do
        classification :core
        aggregate("Invoice") { attribute :amount, Float; command("CreateInvoice") { attribute :amount, Float } }
      end
      output = Hecks::DslSerializer.new(domain).serialize
      expect(output).to include("classification :core")
    end

    it "omits classification when :supporting (the default)" do
      domain = Hecks.domain("Notifications") do
        aggregate("Email") { attribute :to, String; command("SendEmail") { attribute :to, String } }
      end
      output = Hecks::DslSerializer.new(domain).serialize
      expect(output).not_to include("classification")
    end

    it "emits classification :generic in DSL output" do
      domain = Hecks.domain("Auth") do
        classification :generic
        aggregate("User") { attribute :email, String; command("CreateUser") { attribute :email, String } }
      end
      output = Hecks::DslSerializer.new(domain).serialize
      expect(output).to include("classification :generic")
    end
  end
end
