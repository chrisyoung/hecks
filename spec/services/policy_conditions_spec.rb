require "spec_helper"

RSpec.describe "Policy conditions" do
  let(:domain) do
    Hecks.domain "PolicyConditions" do
      aggregate "Account" do
        attribute :balance, Float

        command "Withdraw" do
          attribute :amount, Float
        end

        command "FlagSuspicious" do
          attribute :amount, Float
        end

        command "LogWithdrawal" do
          attribute :amount, Float
        end

        policy "FraudAlert" do
          on "Withdrew"
          trigger "FlagSuspicious"
          condition { |event| event.amount > 10_000 }
        end

        policy "AuditLog" do
          on "Withdrew"
          trigger "LogWithdrawal"
        end
      end
    end
  end

  it "fires a policy when condition is met" do
    app = Hecks.load(domain, force: true)

    app.run("Withdraw", amount: 15_000.0)

    event_names = app.events.map { |e| e.class.name.split("::").last }
    expect(event_names).to include("FlaggedSuspicious")
  end

  it "skips a policy when condition is not met" do
    app = Hecks.load(domain, force: true)

    app.run("Withdraw", amount: 500.0)

    event_names = app.events.map { |e| e.class.name.split("::").last }
    expect(event_names).not_to include("FlaggedSuspicious")
  end

  it "always fires a policy without a condition (backward compat)" do
    app = Hecks.load(domain, force: true)

    app.run("Withdraw", amount: 500.0)

    event_names = app.events.map { |e| e.class.name.split("::").last }
    expect(event_names).to include("LoggedWithdrawal")
  end

  it "stores the condition in the DSL builder" do
    policy = domain.aggregates.first.policies.find { |p| p.name == "FraudAlert" }
    expect(policy.condition).to be_a(Proc)
  end

  it "stores nil condition for policies without one" do
    policy = domain.aggregates.first.policies.find { |p| p.name == "AuditLog" }
    expect(policy.condition).to be_nil
  end

  it "generates reactive policy without condition in output (runtime-only)" do
    policy = domain.aggregates.first.policies.find { |p| p.name == "FraudAlert" }
    gen = Hecks::Generators::Domain::PolicyGenerator.new(
      policy, domain_module: "PolicyConditionsDomain", aggregate_name: "Account"
    )
    output = gen.generate
    # Conditions are evaluated at runtime from the domain IR, not in generated code
    expect(output).to include("def self.event")
    expect(output).not_to include("condition")
  end

  it "serializes the condition in DSL output" do
    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).to include("condition { |event|")
  end

  it "does not serialize condition for policies without one" do
    source = Hecks::DslSerializer.new(domain).serialize
    # AuditLog policy should not have condition
    lines = source.lines
    audit_idx = lines.index { |l| l.include?('"AuditLog"') }
    # Find the end of the AuditLog policy block
    end_idx = lines[audit_idx..].index { |l| l.strip == "end" }
    audit_block = lines[audit_idx..(audit_idx + end_idx)].join
    expect(audit_block).not_to include("condition")
  end
end
