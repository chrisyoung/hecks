require "spec_helper"
require "open3"

RSpec.describe "Example smoke tests" do
  let(:root) { File.expand_path("../..", __dir__) }

  def run_example(path)
    Open3.capture2e("ruby", "-Ilib", path, chdir: root)
  end

  describe "pizzas/app.rb" do
    it "runs without error" do
      output, status = run_example("examples/pizzas/app.rb")
      expect(status.success?).to be(true), "failed:\n#{output}"
    end
  end

  describe "multi_domain/app.rb" do
    it "runs and shows cross-domain events" do
      output, status = run_example("examples/multi_domain/app.rb")
      expect(status.success?).to be(true), "failed:\n#{output}"
      expect(output).to include("CreatedPizza")
    end
  end

  describe "pizzas_static_go" do
    it "binary exists" do
      expect(File.exist?(File.join(root, "examples", "pizzas", "pizzas_static_go", "pizzas_server"))).to be(true)
    end
  end

  describe "pizzas_domain" do
    it "gemspec and lib files exist" do
      dir = File.join(root, "examples", "pizzas_domain")
      expect(File.exist?(File.join(dir, "pizzas_domain.gemspec"))).to be(true)
      expect(Dir[File.join(dir, "lib", "**", "*.rb")]).not_to be_empty
    end
  end

  describe "pizzas_rails" do
    it "Gemfile references hecks and domain" do
      gemfile = File.read(File.join(root, "examples", "pizzas_rails", "Gemfile"))
      expect(gemfile).to include('gem "hecks"')
      expect(gemfile).to include("pizzas_domain")
    end
  end

  describe "governance_static_go" do
    it "binary exists" do
      expect(File.exist?(File.join(root, "examples", "governance_static_go", "governance_server"))).to be(true)
    end
  end
end
