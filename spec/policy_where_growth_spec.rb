require "spec_helper"
require "tempfile"

# Real dispatch coverage for policy `where field: value` -- finding #11:
# a policy only reacts when the triggering event's own payload matches;
# a mismatch isn't a refusal, the policy just doesn't apply to this
# event.
#
# `meta_validation: false` -- the self-hosted grammar's own Policy
# contract doesn't carry `wheres` through its own Judge round-trip yet
# (a separate, later-landing item in this split); turned off here so
# what's under test is this PR's own DSL/interpreter pair.
RSpec.describe "a policy's own where clause" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["policy-where-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds)
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  POLICY_WHERE_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "AlarmGrowth" do
      aggregate "GrowthSensor" do
        identified_by { id.value }

        value_object "GrowthSensorId" do
          attribute :value, String
        end

        value_object "GrowthStatus" do
          attribute :value, String, default: "quiet"
        end

        attribute :id,     GrowthSensorId
        attribute :status, GrowthStatus

        # `severity` is deliberately NOT an aggregate field — a bare
        # command argument the policy's where-clause reads straight off
        # the emitted event's own payload, avoiding this stack point's
        # separate (later-landing) bare-scalar-to-single-field-VO
        # coercion gap entirely.
        command "Report" do
          attribute :id,       GrowthSensorId
          attribute :severity, String
          emits "Reported"
        end

        command "Alert" do
          reference_to GrowthSensor
          attribute :severity, String, optional: true
          then_set :status, to: { value: "alerted" }
        end

        policy "AlertOnCritical" do
          on "Reported"
          where severity: "critical"
          trigger "GrowthSensor.Alert"
        end
      end
    end
  BLUEBOOK

  def boot_alarm
    boot(POLICY_WHERE_SOURCE, "AlarmGrowth") { ::AlarmGrowth::GrowthSensor.persisted_by("Memory") }
  end

  it "fires the trigger when the triggering event's own payload matches the where clause" do
    runtime = boot_alarm
    runtime.dispatch("AlarmGrowth::GrowthSensor.Report", id: { value: "s1" }, severity: "critical")

    expect(runtime.reactions).to contain_exactly(
      hash_including(policy: "AlertOnCritical", on: "Reported",
                     trigger: "AlarmGrowth::GrowthSensor.Alert", delivered: true)
    )
    expect(AlarmGrowth::GrowthSensor.find("s1").status.to_h).to eq(value: "alerted")
  end

  it "does not fire -- and is not a refusal -- when the payload doesn't match" do
    runtime = boot_alarm
    runtime.dispatch("AlarmGrowth::GrowthSensor.Report", id: { value: "s2" }, severity: "normal")

    expect(runtime.reactions).to be_empty
    expect(AlarmGrowth::GrowthSensor.find("s2").status.to_h).to eq(value: "quiet")
  end
end
