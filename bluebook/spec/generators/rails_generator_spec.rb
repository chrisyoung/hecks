require "spec_helper"
require "tmpdir"
require "hecks/generators/rails_generator"

RSpec.describe Hecks::Generators::RailsGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  let(:tmpdir) { Dir.mktmpdir }
  let(:generator) { described_class.new(domain) }
  let(:app_root) { File.join(tmpdir, "pizzas_rails") }

  after { FileUtils.rm_rf(tmpdir) }

  # Stub rails new — create minimal structure instead
  before do
    allow(generator).to receive(:system).and_return(true)
    FileUtils.mkdir_p(app_root)
    File.write(File.join(app_root, "Gemfile"), <<~GEM)
      source "https://rubygems.org"
      gem "rails"
      gem "puma"
    GEM

    # Fake welcome page ERB for patch_welcome_page to find
    railties = ::Gem.loaded_specs["railties"]
    if railties
      source = File.join(railties.full_gem_path, "lib/rails/templates/rails/welcome/index.html.erb")
      @has_welcome = File.exist?(source)
    end

    generator.generate(output_dir: tmpdir)
  end

  describe "Gemfile" do
    let(:gemfile) { File.read(File.join(app_root, "Gemfile")) }

    it "adds hecks gem" do
      expect(gemfile).to include('gem "hecks"')
    end

    it "adds domain gem as sibling path" do
      expect(gemfile).to include('gem "pizzas_domain", path: "../pizzas_domain"')
    end
  end

  describe "Gemfile with source_path" do
    let(:gemfile) { File.read(File.join(app_root, "Gemfile")) }

    before do
      # Simulate a domain loaded from examples/pizzas/hecks_domain.rb
      project_root = File.expand_path("../../../..", __dir__)
      domain.source_path = File.join(project_root, "examples", "pizzas", "hecks_domain.rb")
      generator.generate(output_dir: tmpdir)
    end

    it "uses a relative path for hecks" do
      expect(gemfile).to match(/gem "hecks", path: ".*"/)
      expect(gemfile).not_to include("gem \"hecks\"\n")
    end
  end

  describe "initializer" do
    let(:init) { File.read(File.join(app_root, "config", "initializers", "hecks.rb")) }

    it "creates config/initializers/hecks.rb" do
      expect(File.exist?(File.join(app_root, "config", "initializers", "hecks.rb"))).to be true
    end

    it "requires hecks and the domain gem" do
      expect(init).to include('require "hecks"')
      expect(init).to include('require "pizzas_domain"')
    end

    it "configures the domain with memory adapter" do
      expect(init).to include('domain "pizzas_domain"')
      expect(init).to include("adapter :memory")
    end
  end

  describe "welcome page", if: ::Gem.loaded_specs["railties"] do
    let(:index) { File.join(app_root, "public", "index.html") }

    it "creates public/index.html" do
      skip "railties not available" unless @has_welcome
      expect(File.exist?(index)).to be true
    end

    it "includes Hecks version" do
      skip "railties not available" unless @has_welcome
      html = File.read(index)
      expect(html).to include("Hecks version:")
      expect(html).to include(Hecks::VERSION)
    end

    it "includes animated border CSS" do
      skip "railties not available" unless @has_welcome
      html = File.read(index)
      expect(html).to include("border-rotate")
      expect(html).to include("conic-gradient")
    end

    it "includes hecks-version shimmer CSS" do
      skip "railties not available" unless @has_welcome
      html = File.read(index)
      expect(html).to include(".hecks-version")
      expect(html).to include("hecks-shimmer")
    end

    it "adds animated gradient ring around the Rails logo" do
      skip "railties not available" unless @has_welcome
      html = File.read(index)
      expect(html).to include("nav a::before")
      expect(html).to include("conic-gradient(from var(--angle)")
    end

    it "resolves ERB tags to static values" do
      skip "railties not available" unless @has_welcome
      html = File.read(index)
      expect(html).not_to include("<%=")
    end
  end

  it "returns the app root path" do
    result = generator.generate(output_dir: tmpdir)
    expect(result).to eq(app_root)
  end
end
