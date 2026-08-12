require "spec_helper"
require "tempfile"

# Real coverage for CommandBuilder#role's STRUCTURED form: `role Role,
# as: Agent` (i483) -- role.bluebook's own vision: "Role is the type ;
# Agent is the role-bearer... reads as 'this command runs in the role
# of Role, and the role-bearer is referenced as Agent in the command's
# attribute scope'."
#
# Synthesises a reference_to the role-bearer type (`as: Agent` -> an
# `agent` attribute, a bare opaque-identity String, deliberately NOT a
# real `reference_to` -- Agent is referenced cross-domain from many
# different domains' commands, and a structural reference back to it
# fails from every domain except Agent's own) and keeps `@role` as the
# role TYPE's own name so existing string-role authorization code still
# has something to compare against. Extra kwargs (`kind:`) are recorded
# but not enforced.
RSpec.describe "CommandBuilder role Role, as: Agent" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["command-role-as-agent-growth-", ".bluebook"])
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

  STRUCTURED_ROLE_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "CommandRoleAsAgentGrowth" do
      aggregate "Task" do
        identified_by { task_id.value }

        value_object "TaskId" do
          attribute :value, String
        end

        attribute :task_id, TaskId

        command "Create" do
          attribute :task_id, TaskId
          emits "TaskCreated"
        end

        command "Claim" do
          reference_to Task
          role Role, as: Agent, kind: "worker"
          emits "TaskClaimed"
        end
      end
    end
  BLUEBOOK

  def repository_for(runtime)
    bluebook = runtime.registry.bluebook("CommandRoleAsAgentGrowth")
    aggregate = bluebook.aggregate("Task")
    runtime.registry.repository("CommandRoleAsAgentGrowth", aggregate)
  end

  def boot_structured_role
    boot(STRUCTURED_ROLE_SOURCE, "CommandRoleAsAgentGrowth") do
      ::CommandRoleAsAgentGrowth::Task.persisted_by("Memory")
    end
  end

  it "synthesises a bearer attribute (agent) rather than a structural reference_to" do
    runtime = boot_structured_role
    task = runtime.registry.bluebook("CommandRoleAsAgentGrowth").aggregate("Task")
    claim = task.command("Claim")

    field = claim.attributes.find { |a| a.name == :agent }
    expect(field).not_to be_nil
    expect(field.type.to_s).to eq("String")
  end

  it "keeps @role set to the role TYPE's own name, for existing string-role authorization code" do
    runtime = boot_structured_role
    task = runtime.registry.bluebook("CommandRoleAsAgentGrowth").aggregate("Task")
    claim = task.command("Claim")

    expect(claim.role).to eq("Role")
  end

  it "dispatches a real command carrying the bearer attribute" do
    runtime = boot_structured_role
    runtime.dispatch("CommandRoleAsAgentGrowth::Task.Create", task_id: { value: "t1" })

    expect do
      runtime.dispatch("CommandRoleAsAgentGrowth::Task.Claim",
                        task_id: { value: "t1" }, agent: "agent-42")
    end.not_to raise_error
  end

  it "role declared twice still raises, structured or not" do
    expect do
      Hecksagain::Bluebook::DSL::CommandBuilder.build("DoubleRole", owner: "Task") do
        role "Creator"
        role "Creator", as: "SomethingElse"
      end
    end.to raise_error(Hecksagain::Bluebook::DSL::Malformed, /declares role twice/)
  end

  it "the plain string form (no as:) still works exactly as before" do
    command = Hecksagain::Bluebook::DSL::CommandBuilder.build("PlainRole", owner: "Task") do
      role "Creator"
    end
    expect(command.role).to eq("Creator")
  end
end
