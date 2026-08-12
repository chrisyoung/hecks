require "spec_helper"
require "tmpdir"

# Real coverage for EraCheck#source_text_for's content-matching fix: a
# domain's own bluebook file used to be found by FILENAME
# (Naming.pascal(basename) == bluebook.name), which breaks once a corpus is
# flattened into one numeric-prefixed staging directory (042_foo.bluebook)
# or has a filename that doesn't round-trip through Naming.pascal at all
# (embryonautfoundersapp.bluebook pascal-cases to "Embryonautfoundersapp",
# never "EmbryonautFoundersApp" -- the declared name's own internal
# capitalization is lost the moment the filename has no word boundaries to
# carry it). Fixed by reading each candidate file's own
# `Hecks.bluebook "Name"` declaration line and matching it directly.
RSpec.describe "EraCheck#source_text_for matches by declared name, not filename" do
  def bluebook_named(name)
    Hecksagain::Bluebook::IR::Bluebook.new(name: name)
  end

  it "finds a file whose name never round-trips through Naming.pascal" do
    Dir.mktmpdir do |dir|
      own_path = File.join(dir, "embryonautfoundersapp.bluebook")
      File.write(own_path, "Hecks.bluebook \"EmbryonautFoundersApp\" do\nend\n")

      # a second file in the same directory defeats the single-file
      # fallback, forcing a real match to be found
      File.write(File.join(dir, "translations.bluebook"), "Hecks.data_translation(\"Other\", from: \"1\", to: \"2\") do\nend\n")

      bluebook = bluebook_named("EmbryonautFoundersApp")

      text = Hecksagain::Runtime::EraCheck.source_text_for(bluebook, dir)
      expect(text).to eq(File.read(own_path))
    end
  end

  it "finds a file flattened into a numeric-prefixed staging directory" do
    Dir.mktmpdir do |dir|
      own_path = File.join(dir, "042_shaped_growth.bluebook")
      File.write(own_path, "Hecks.bluebook \"ShapedGrowth\" do\nend\n")

      File.write(File.join(dir, "999_other_growth.bluebook"), "Hecks.bluebook \"OtherGrowth\" do\nend\n")

      bluebook = bluebook_named("ShapedGrowth")

      text = Hecksagain::Runtime::EraCheck.source_text_for(bluebook, dir)
      expect(text).to eq(File.read(own_path))
    end
  end

  it "still falls through to the basename heuristic when content-match misses" do
    Dir.mktmpdir do |dir|
      # no `Hecks.bluebook "Name"` line at all on this one -- an edge case
      # the content match cannot resolve, so the old heuristic must still
      # catch it
      own_path = File.join(dir, "legacy_growth.bluebook")
      File.write(own_path, "# no declaration line here\n")

      File.write(File.join(dir, "other_growth.bluebook"), "Hecks.bluebook \"OtherGrowth\" do\nend\n")

      bluebook = bluebook_named("LegacyGrowth")

      text = Hecksagain::Runtime::EraCheck.source_text_for(bluebook, dir)
      expect(text).to eq(File.read(own_path))
    end
  end
end
