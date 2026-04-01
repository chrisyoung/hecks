require "spec_helper"

RSpec.describe "Custom world goals" do
  def validate(domain)
    validator = Hecks::Validator.new(domain)
    [validator.valid?, validator.errors, validator]
  end

  after do
    # Clean up custom goal constants and rule registrations
    %i[Compliance AuditTrail].each do |name|
      if Hecks::ValidationRules::WorldGoals.const_defined?(name)
        klass = Hecks::ValidationRules::WorldGoals.const_get(name)
        Hecks.deregister_validation_rule(klass)
        Hecks::ValidationRules::WorldGoals.send(:remove_const, name)
      end
    end
  end

  it "defines a custom goal that validates the domain" do
    Hecks.define_goal(:compliance) do
      validate do |domain|
        domain.aggregates.flat_map do |agg|
          agg.commands.select { |c| c.actors.empty? }.map do |cmd|
            "#{agg.name}##{cmd.name} has no actor"
          end
        end
      end
    end

    domain = Hecks.domain "Regulated" do
      world_goals :compliance
      aggregate "Report" do
        attribute :title, String
        command "FileReport" do
          attribute :title, String
        end
      end
    end

    valid, errors, = validate(domain)
    expect(valid).to be false
    expect(errors).to include(/Compliance.*Report#FileReport.*no actor/)
  end

  it "passes when the custom goal has no violations" do
    Hecks.define_goal(:compliance) do
      validate do |domain|
        domain.aggregates.flat_map do |agg|
          agg.commands.select { |c| c.actors.empty? }.map do |cmd|
            "#{agg.name}##{cmd.name} has no actor"
          end
        end
      end
    end

    domain = Hecks.domain "Compliant" do
      world_goals :compliance
      aggregate "Report" do
        attribute :title, String
        command "FileReport" do
          attribute :title, String
          actor "Auditor"
        end
      end
    end

    valid, = validate(domain)
    expect(valid).to be true
  end

  it "does not fire when the goal is not declared" do
    Hecks.define_goal(:compliance) do
      validate { |_domain| ["always fails"] }
    end

    domain = Hecks.domain "NoGoals" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end

    valid, = validate(domain)
    expect(valid).to be true
  end

  it "records required extensions on the rule" do
    Hecks.define_goal(:audit_trail) do
      requires_extension :audit
      requires_extension :logging
      validate { |_domain| [] }
    end

    rule = Hecks::ValidationRules::WorldGoals::AuditTrail
    instance = rule.new(Hecks.domain("X") { aggregate("A") { attribute :n, String; command("C") { attribute :n, String } } })
    expect(instance.required_extensions).to eq([:audit, :logging])
  end

  it "shows in mother_earth_report when failing" do
    Hecks.define_goal(:compliance) do
      validate { |_domain| ["everything is wrong"] }
    end

    domain = Hecks.domain "Bad" do
      world_goals :compliance
      aggregate "Thing" do
        attribute :name, String
        command "DoThing" do
          attribute :name, String
        end
      end
    end

    _, _, validator = validate(domain)
    report = validator.mother_earth_report
    expect(report[:goals_declared]).to include(:compliance)
    expect(report[:failing_goals]).to include(:compliance)
    expect(report[:violations]).to include(/Compliance/)
  end
end
