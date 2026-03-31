require "spec_helper"

RSpec.describe "CLI domain resolution" do
  describe "find_installed_domains" do
    it "finds gems with Bluebook" do
      cli = Hecks::CLI.new
      domains = cli.send(:find_installed_domains)
      # pizzas_domain should be installed from our test setup
      names = domains.map(&:first)
      expect(names).to include("pizzas_domain") if Gem::Specification.any? { |s| s.name == "pizzas_domain" }
    end
  end

  describe "resolve_domain" do
    let(:cli) { Hecks::CLI.new }

    it "resolves from a directory with Bluebook" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "PizzasBluebook"), 'Hecks.domain("Test") { aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } } }')
        domain = cli.send(:resolve_domain, dir)
        expect(domain.name).to eq("Test")
      end
    end

    it "returns nil for nonexistent path" do
      domain = cli.send(:resolve_domain, "/nonexistent/path")
      expect(domain).to be_nil
    end
  end
end
