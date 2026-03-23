require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Configuration do
  let(:domain) do
    Hecks.domain "TestConfig" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  describe "multi-domain" do
    it "boots multiple domains with shared event bus" do
      domain_a = Hecks.domain "DomainA" do
        aggregate "Thing" do
          attribute :name, String
          command "CreateThing" do
            attribute :name, String
          end
        end
      end

      domain_b = Hecks.domain "DomainB" do
        aggregate "Other" do
          attribute :name, String
          command "CreateOther" do
            attribute :name, String
          end
        end
      end

      tmpdir = Dir.mktmpdir("hecks_config_test")
      [domain_a, domain_b].each do |d|
        gem_path = Hecks.build(d, output_dir: tmpdir)
        lib_path = File.join(gem_path, "lib")
        $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
        require d.gem_name
        Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
      end

      shared_bus = Hecks::Services::EventBus.new
      app_a = Hecks::Services::Application.new(domain_a, event_bus: shared_bus)
      app_b = Hecks::Services::Application.new(domain_b, event_bus: shared_bus)

      DomainADomain::Thing.create(name: "test")
      expect(shared_bus.events.size).to eq(1)
      expect(app_a.events.size).to eq(1)
      expect(app_b.events.size).to eq(1)
    end
  end
end
