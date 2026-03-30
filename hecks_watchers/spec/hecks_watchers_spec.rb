require "spec_helper"
require "hecks_watchers"

RSpec.describe HecksWatchers do
  it "defines all watcher classes" do
    expect(defined?(HecksWatchers::FileSize)).to be_truthy
    expect(defined?(HecksWatchers::CrossRequire)).to be_truthy
    expect(defined?(HecksWatchers::SpecCoverage)).to be_truthy
    expect(defined?(HecksWatchers::Runner)).to be_truthy
    expect(defined?(HecksWatchers::LogReader)).to be_truthy
    expect(defined?(HecksWatchers::Logger)).to be_truthy
  end
end
