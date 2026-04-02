require "spec_helper"

RSpec.describe "Custom Concerns" do
  after { Hecks.custom_concerns.clear! }

  describe "Hecks.concern DSL" do
    it "registers a custom concern with the ConcernBuilder" do
      Hecks.concern :hipaa_compliance do
        description "HIPAA compliance for healthcare data"
        requires_extension :pii
        requires_extension :audit
        rule "PII must be hidden" do |aggregate|
          aggregate.attributes.select(&:pii?).all? { |a| !a.visible? }
        end
      end

      concern = Hecks.find_concern(:hipaa_compliance)
      expect(concern).not_to be_nil
      expect(concern.name).to eq(:hipaa_compliance)
      expect(concern.description).to eq("HIPAA compliance for healthcare data")
      expect(concern.required_extensions).to eq([:pii, :audit])
      expect(concern.rules.size).to eq(1)
      expect(concern.rules.first.name).to eq("PII must be hidden")
    end

    it "overwrites an existing concern with the same name" do
      Hecks.concern(:test) { description "v1" }
      Hecks.concern(:test) { description "v2" }

      expect(Hecks.find_concern(:test).description).to eq("v2")
      expect(Hecks.custom_concerns.all.size).to eq(1)
    end
  end

  describe "ConcernRegistry" do
    let(:registry) { Hecks::CustomConcerns::ConcernRegistry.new }

    it "stores and retrieves concerns" do
      concern = Hecks::CustomConcerns::Concern.new(name: :gdpr, description: "GDPR")
      registry.register(concern)

      expect(registry.find(:gdpr)).to eq(concern)
      expect(registry.names).to eq([:gdpr])
      expect(registry.registered?(:gdpr)).to be true
      expect(registry.registered?(:unknown)).to be false
    end

    it "clears all concerns" do
      registry.register(Hecks::CustomConcerns::Concern.new(name: :a))
      registry.register(Hecks::CustomConcerns::Concern.new(name: :b))
      registry.clear!

      expect(registry.all).to be_empty
    end
  end

  describe "ConcernBuilder" do
    it "builds a Concern value object" do
      builder = Hecks::CustomConcerns::ConcernBuilder.new(:gdpr)
      builder.instance_eval do
        description "GDPR compliance"
        requires_extension :pii
        rule("Rule 1") { |_| true }
        rule("Rule 2") { |_| false }
      end

      concern = builder.build
      expect(concern.name).to eq(:gdpr)
      expect(concern.description).to eq("GDPR compliance")
      expect(concern.required_extensions).to eq([:pii])
      expect(concern.rules.size).to eq(2)
    end
  end

  describe "Rule" do
    it "evaluates against an aggregate" do
      passing = Hecks::CustomConcerns::Rule.new("always passes") { |_| true }
      failing = Hecks::CustomConcerns::Rule.new("always fails") { |_| false }
      erroring = Hecks::CustomConcerns::Rule.new("raises") { |_| raise "boom" }

      aggregate = double("aggregate")
      expect(passing.passes?(aggregate)).to be true
      expect(failing.passes?(aggregate)).to be false
      expect(erroring.passes?(aggregate)).to be false
    end
  end

  describe "concerns DSL keyword" do
    it "splits world and custom concerns" do
      Hecks.concern(:hipaa) { description "HIPAA" }

      domain = Hecks.domain "Health" do
        concerns :transparency, :hipaa
        aggregate "Patient" do
          attribute :name, String
          command("CreatePatient") { attribute :name, String }
        end
      end

      expect(domain.world_concerns).to include(:transparency)
      expect(domain.custom_concerns).to include(:hipaa)
    end

    it "works alongside world_concerns keyword" do
      Hecks.concern(:sox) { description "SOX" }

      domain = Hecks.domain "Finance" do
        world_concerns :transparency
        concerns :sox
        aggregate "Account" do
          attribute :name, String
          command("CreateAccount") { attribute :name, String }
        end
      end

      expect(domain.world_concerns).to eq([:transparency])
      expect(domain.custom_concerns).to eq([:sox])
    end
  end

  describe "GovernanceGuard integration" do
    it "checks custom concern rules against aggregates" do
      Hecks.concern :pii_hidden do
        description "PII must not be visible"
        rule "PII fields must be hidden" do |aggregate|
          aggregate.attributes.select(&:pii?).all? { |a| !a.visible? }
        end
      end

      domain = Hecks.domain "Health" do
        concerns :pii_hidden
        aggregate "Patient" do
          attribute :ssn, String, pii: true
          command("CreatePatient") { attribute :ssn, String }
        end
      end

      result = Hecks::GovernanceGuard.new(domain).check
      expect(result.passed?).to be false
      expect(result.violations.first[:concern]).to eq(:pii_hidden)
      expect(result.violations.first[:message]).to include("Patient")
    end

    it "passes when all custom concern rules pass" do
      Hecks.concern :pii_hidden do
        rule "PII fields must be hidden" do |aggregate|
          aggregate.attributes.select(&:pii?).all? { |a| !a.visible? }
        end
      end

      domain = Hecks.domain "Health" do
        concerns :pii_hidden
        aggregate "Patient" do
          attribute :ssn, String, pii: true, visible: false
          command("CreatePatient") { attribute :ssn, String }
        end
      end

      expect(Hecks::GovernanceGuard.new(domain).check.passed?).to be true
    end
  end

  describe "Validator integration" do
    it "includes custom concern violations in validation errors" do
      Hecks.concern :must_have_commands do
        rule "Aggregate must have at least two commands" do |aggregate|
          aggregate.commands.size >= 2
        end
      end

      domain = Hecks.domain "Simple" do
        concerns :must_have_commands
        aggregate "Widget" do
          attribute :name, String
          command("CreateWidget") { attribute :name, String }
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      custom_errors = validator.errors.select { |e| e.to_s.include?("CustomConcern") }
      expect(custom_errors).not_to be_empty
      expect(custom_errors.first.to_s).to include("must_have_commands")
    end
  end
end
