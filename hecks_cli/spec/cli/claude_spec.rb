require "spec_helper"

RSpec.describe "hecks claude CLI command" do
  it "is registered as a top-level command" do
    expect(Hecks::CLI.commands).to include("claude")
  end

  it "locates the hecks_claude script" do
    cli = Hecks::CLI.new
    expect(cli).to receive(:exec).with(a_string_ending_with("hecks_claude"))
    cli.claude
  end

  it "forwards extra arguments to the script" do
    cli = Hecks::CLI.new
    expect(cli).to receive(:exec).with(a_string_ending_with("hecks_claude"), "--resume")
    cli.claude("--resume")
  end
end
