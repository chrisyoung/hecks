require "hecks"
require "hecks/benchmarks"

RSpec.describe Hecks::Benchmarks::Timer do
  it "runs the block N times and returns min/median/max" do
    counter = 0
    result = described_class.measure(iterations: 5) { counter += 1 }

    expect(counter).to eq(5)
    expect(result).to have_key(:min)
    expect(result).to have_key(:median)
    expect(result).to have_key(:max)
    expect(result).to have_key(:times)
    expect(result[:times].length).to eq(5)
    expect(result[:min]).to be <= result[:median]
    expect(result[:median]).to be <= result[:max]
  end

  it "handles even iteration counts for median" do
    result = described_class.measure(iterations: 4) { nil }

    expect(result[:times].length).to eq(4)
    expect(result[:median]).to be_a(Float)
  end
end
