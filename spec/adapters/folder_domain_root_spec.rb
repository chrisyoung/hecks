require "spec_helper"

# THE DOMAIN YOU ARE STANDING IN — what lets `bin/docs` and `bin/run` take no
# domain argument at all when the working directory is already inside one.
RSpec.describe Hecksagain::Adapters::Folder do
  subject(:folder) { described_class.new }

  let(:root)    { InMemoryDomain::ROOT }
  let(:banking) { File.join(root, "examples/banking") }

  describe "#domain_root" do
    it "answers a domain directory with itself" do
      expect(folder.domain_root(banking)).to eq(banking)
    end

    it "walks up from anywhere inside it" do
      expect(folder.domain_root(File.join(banking, "bluebook"))).to eq(banking)
      expect(folder.domain_root(File.join(banking, "data"))).to eq(banking)
    end

    # A `.hecksagon` IS THE MARKER, NOT A `.bluebook`. Chapters are
    # everywhere — era translations, the self-hosted grammar, and
    # `spec/fixtures`, which holds a dozen unrelated ones in one directory and
    # would answer with whichever happened to load first.
    it "does not mistake a directory of chapters for a domain" do
      fixtures = File.join(root, "spec/fixtures")
      expect(Dir[File.join(fixtures, "*.bluebook")]).not_to be_empty
      expect(folder.domain_root(fixtures)).not_to eq(fixtures)
    end

    it "answers nil above every domain, rather than guessing" do
      # The repository root declares no hecksagon of its own, and neither does
      # anything above it.
      expect(folder.domain_root(root)).to be_nil
    end

    # BOTH LAYOUTS ARE REAL DOMAINS to `#domain?` — `bluebook_directory`
    # accepts either, and a boot of either produces the same registry root.
    # `#domain_root` normalises to the outer one because that is the directory
    # a person names and the one a `.world`'s `dir "data"` is relative to.
    it "accepts both layouts a boot accepts, and names the outer one" do
      inner = File.join(banking, "bluebook")

      expect(folder).to be_domain(banking)
      expect(folder).to be_domain(inner)
      expect(folder.domain_root(inner)).to eq(banking)
    end
  end
end
