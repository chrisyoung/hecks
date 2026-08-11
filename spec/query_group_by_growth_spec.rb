require "spec_helper"
require "tempfile"

# Real dispatch coverage for `group_by :field` — finding #10, a third
# query-aggregation shape alongside `count`/`median`: partitions the
# where-filtered set by a field's value and tallies each partition, one
# row per distinct value, ordered by count descending then by the value
# itself.
#
# `meta_validation: false` — the self-hosted grammar's own Query
# contract doesn't carry `group_by_field` through its own Judge round-trip
# yet (a separate, later-landing item in this split); turned off here so
# what's under test is this PR's own DSL/interpreter pair, not that
# separate gap.
RSpec.describe "a query's own group_by" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["group-by-growth-", ".bluebook"])
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

  GROUP_BY_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "ScoreboardGrowth" do
      aggregate "Submission" do
        identified_by { id.value }

        value_object "SubmissionId" do
          attribute :value, String
        end

        attribute :id,     SubmissionId
        attribute :player, String
        attribute :points, Integer

        command "Submit" do
          attribute :id,     SubmissionId
          attribute :player, String
          attribute :points, Integer
          emits "Submitted"
        end

        query "PerPlayer" do
          group_by :player
        end
      end
    end
  BLUEBOOK

  def boot_scoreboard
    boot(GROUP_BY_SOURCE, "ScoreboardGrowth") do
      ::ScoreboardGrowth::Submission.persisted_by("Memory")
    end
  end

  it "tallies rows into one row per distinct group value, ordered by count then value" do
    runtime = boot_scoreboard
    runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s1" }, player: "Ada",   points: 10)
    runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s2" }, player: "Ada",   points: 20)
    runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s3" }, player: "Grace", points: 5)
    runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s4" }, player: "Ada",   points: 1)

    rows = runtime.query("ScoreboardGrowth::Submission.PerPlayer")

    expect(rows).to eq([{ player: "Ada", count: 3 }, { player: "Grace", count: 1 }])
  end

  it "breaks a tie in count by the group value itself, so the order is deterministic" do
    runtime = boot_scoreboard
    runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s1" }, player: "Zed", points: 1)
    runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s2" }, player: "Amy", points: 1)

    rows = runtime.query("ScoreboardGrowth::Submission.PerPlayer")

    expect(rows).to eq([{ player: "Amy", count: 1 }, { player: "Zed", count: 1 }])
  end
end
