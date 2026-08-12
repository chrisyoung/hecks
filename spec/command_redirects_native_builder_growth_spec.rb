require "spec_helper"

# Real coverage for CommandBuilder#redirects_native -- the DSL BUILDER
# half of the `redirects_native` construct. The IR/contracts/self-hosted
# -grammar side already landed (split-plan item 05, PR #22); nothing
# could actually CALL `redirects_native "Read"` from a real `.bluebook`
# file until THIS lands.
#
# Honest scope note: landing this alone does not yet close
# `plan_spec.rb`/`plurality_coverage_spec.rb`/`judge_coverage_spec.rb`'s
# own `redirects_native` gaps for real -- those also need a corpus
# fixture actually USING the construct (banking.bluebook's
# `redirects_native "ComplianceHold"` line), which is separate, later
# migration content, not this DSL builder method.
RSpec.describe "CommandBuilder#redirects_native" do
  it "captures a single tool name" do
    command = Hecksagain::Bluebook::DSL::CommandBuilder.build("SingleTool", owner: "Thing") do
      redirects_native "Bash"
      emits "Done"
    end

    expect(command.redirects_native).to eq(["Bash"])
  end

  it "captures multiple tool names in one call" do
    command = Hecksagain::Bluebook::DSL::CommandBuilder.build("MultiTool", owner: "Thing") do
      redirects_native "Edit", "MultiEdit", "NotebookEdit"
      emits "Done"
    end

    expect(command.redirects_native).to eq(%w[Edit MultiEdit NotebookEdit])
  end

  it "defaults to an empty list when never called -- no behavior change for every other command" do
    command = Hecksagain::Bluebook::DSL::CommandBuilder.build("NoRedirect", owner: "Thing") do
      emits "Done"
    end

    expect(command.redirects_native).to eq([])
  end
end
