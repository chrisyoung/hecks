require "spec_helper"
require "tmpdir"

RSpec.describe "Hecks top-level API" do
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

  describe "Hecks.session" do
    it "returns a Session" do
      session = Hecks.session("Test")
      expect(session).to be_a(Hecks::Session)
    end
  end

  describe "Hecks.validate" do
    it "returns [true, []] for a valid domain" do
      valid, errors = Hecks.validate(domain)
      expect(valid).to be true
      expect(errors).to be_empty
    end

    it "returns [false, errors] for an invalid domain" do
      bad_domain = Hecks.domain "Bad" do
        aggregate "Order" do
          attribute :widget_id, reference_to("Widget")
          command "PlaceOrder" do
            attribute :widget_id, reference_to("Widget")
          end
        end
      end

      valid, errors = Hecks.validate(bad_domain)
      expect(valid).to be false
      expect(errors).not_to be_empty
    end
  end

  describe "Hecks.build" do
    it "generates a domain gem" do
      tmpdir = Dir.mktmpdir
      path = Hecks.build(domain, version: "1.0.0", output_dir: tmpdir)

      expect(Dir.exist?(path)).to be true
      expect(File.exist?(File.join(path, "lib/pizzas_domain.rb"))).to be true

      FileUtils.rm_rf(tmpdir)
    end

    it "raises on invalid domain" do
      bad_domain = Hecks.domain "Bad" do
        aggregate "Order" do
          attribute :widget_id, reference_to("Widget")
          command "PlaceOrder" do
            attribute :widget_id, reference_to("Widget")
          end
        end
      end

      expect { Hecks.build(bad_domain) }.to raise_error(/validation failed/i)
    end
  end

  describe "Hecks.preview" do
    it "returns generated code for an aggregate" do
      code = Hecks.preview(domain, "Pizza")
      expect(code).to include("class Pizza")
      expect(code).to include("attribute :name")
    end

    it "raises for unknown aggregate" do
      expect { Hecks.preview(domain, "Nope") }.to raise_error(/Unknown aggregate/)
    end
  end
end
