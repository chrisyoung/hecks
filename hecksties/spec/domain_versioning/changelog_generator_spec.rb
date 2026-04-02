require "spec_helper"

RSpec.describe Hecks::DomainVersioning::ChangelogGenerator do
  let(:domain_v1) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  let(:domain_v2) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :size, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  describe ".generate_diff" do
    it "produces Markdown with breaking and non-breaking sections" do
      md = described_class.generate_diff(domain_v2, domain_v1, version: "2.0.0")

      expect(md).to include("## 2.0.0")
      expect(md).to include("Breaking Changes")
      expect(md).to include("- attribute: Pizza.size")
    end

    it "shows only changes section when no breaking changes" do
      md = described_class.generate_diff(domain_v1, domain_v2, version: "1.1.0")

      expect(md).to include("## 1.1.0")
      expect(md).to include("### Changes")
      expect(md).not_to include("Breaking Changes")
    end

    it "reports no changes when domains are identical" do
      md = described_class.generate_diff(domain_v1, domain_v1, version: "1.0.1")
      expect(md).to include("No changes.")
    end
  end

  describe ".generate" do
    it "returns placeholder when no versions exist" do
      Dir.mktmpdir do |tmpdir|
        md = described_class.generate(base_dir: tmpdir)
        expect(md).to include("No tagged versions found")
      end
    end
  end
end
