require "spec_helper"
require "tempfile"

# Real dispatch coverage for `median :field` -- the same filtered-then-
# reduce shape as `count`, one field further.
#
# `meta_validation: false` for the same reason as this split's other
# query-reduction coverage.
RSpec.describe "a query's own median" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["median-growth-", ".bluebook"])
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

  MEDIAN_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "ConsensusGrowth" do
      aggregate "Estimate" do
        identified_by { id.value }

        value_object "EstimateId" do
          attribute :value, String
        end

        attribute :id,    EstimateId
        attribute :points, Integer

        command "Submit" do
          attribute :id,     EstimateId
          attribute :points, Integer
          emits "Submitted"
        end

        query "MedianPoints" do
          median :points
        end
      end
    end
  BLUEBOOK

  def boot_consensus
    boot(MEDIAN_SOURCE, "ConsensusGrowth") { ::ConsensusGrowth::Estimate.persisted_by("Memory") }
  end

  it "reduces an odd-count filtered set to its sorted middle value" do
    runtime = boot_consensus
    [3, 8, 5].each_with_index do |points, i|
      runtime.dispatch("ConsensusGrowth::Estimate.Submit", id: { value: "e#{i}" }, points: points)
    end

    expect(runtime.query("ConsensusGrowth::Estimate.MedianPoints")).to eq(5)
  end

  it "averages the two middle values on an even-count filtered set" do
    runtime = boot_consensus
    [3, 8, 5, 13].each_with_index do |points, i|
      runtime.dispatch("ConsensusGrowth::Estimate.Submit", id: { value: "e#{i}" }, points: points)
    end

    expect(runtime.query("ConsensusGrowth::Estimate.MedianPoints")).to eq(6.5)
  end
end
