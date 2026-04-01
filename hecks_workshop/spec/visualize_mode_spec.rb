require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Workshop::VisualizeMode do
  subject(:workshop) do
    wb = Hecks::Workshop.new("Pizzas")
    wb.aggregate("Pizza") do
      attribute :name, String
      command "CreatePizza" do
        attribute :name, String
      end
    end
    wb
  end

  before { allow($stdout).to receive(:puts) }

  describe "#visualize (default :print)" do
    it "prints Mermaid markdown to stdout" do
      expect { workshop.visualize }.to output(/mermaid/).to_stdout
    end

    it "includes classDiagram for :structure type" do
      expect { workshop.visualize(:print, type: :structure) }
        .to output(/classDiagram/).to_stdout
    end

    it "includes flowchart for :behavior type" do
      expect { workshop.visualize(:print, type: :behavior) }
        .to output(/flowchart/).to_stdout
    end

    it "includes sequenceDiagram for :flows type" do
      expect { workshop.visualize(:print, type: :flows) }
        .to output(/sequenceDiagram/).to_stdout
    end
  end

  describe "#visualize(:file)" do
    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { example.run }
      end
    end

    it "writes a .md file" do
      workshop.visualize(:file)
      expect(File.exist?("all_diagram.md")).to be true
    end

    it "file contains mermaid blocks" do
      workshop.visualize(:file)
      content = File.read("all_diagram.md")
      expect(content).to include("```mermaid")
    end

    it "writes type-specific filename" do
      workshop.visualize(:file, type: :structure)
      expect(File.exist?("structure_diagram.md")).to be true
    end
  end

  describe "#visualize(:browser)" do
    it "creates an HTML tempfile and opens it" do
      allow(workshop).to receive(:system)
      path = workshop.visualize(:browser)
      expect(File.exist?(path)).to be true
      expect(File.read(path)).to include("<pre class=\"mermaid\">")
    end

    it "HTML includes Mermaid CDN script" do
      allow(workshop).to receive(:system)
      path = workshop.visualize(:browser)
      expect(File.read(path)).to include("mermaid")
    end
  end

  describe "#mermaid_for" do
    let(:domain) { workshop.to_domain }

    it "returns classDiagram for :structure" do
      result = workshop.send(:mermaid_for, domain, :structure)
      expect(result).to include("classDiagram")
    end

    it "returns flowchart for :behavior" do
      result = workshop.send(:mermaid_for, domain, :behavior)
      expect(result).to include("flowchart")
    end

    it "returns sequenceDiagram for :flows" do
      result = workshop.send(:mermaid_for, domain, :flows)
      expect(result).to include("sequenceDiagram")
    end

    it "returns full output for :all" do
      result = workshop.send(:mermaid_for, domain, :all)
      expect(result).to include("classDiagram")
    end
  end
end
