# Bulk Operations Spec
#
# Tests Widget.bulk(:retire, where: { status: "active" }) support,
# composing queries with commands for batch processing.
#
require "spec_helper"

RSpec.describe "Bulk Operations" do
  let(:domain) do
    Hecks.domain "Widgets" do
      aggregate "Widget" do
        attribute :name, String
        attribute :status, String

        command "CreateWidget" do
          attribute :name, String
          attribute :status, String
        end

        command "RetireWidget" do
          reference_to "Widget"
          attribute :status, String
        end
      end
    end
  end

  let!(:app) { Hecks.load(domain) }
  let(:widget_class) { WidgetsDomain::Widget }

  before do
    widget_class.create(name: "Alpha", status: "active")
    widget_class.create(name: "Beta", status: "active")
    widget_class.create(name: "Gamma", status: "retired")
  end

  describe ".bulk" do
    it "is defined on the aggregate class" do
      expect(widget_class).to respond_to(:bulk)
    end

    it "applies command to all matching widgets via where filter" do
      results = widget_class.bulk(:retire, where: { status: "active" })
      expect(results.size).to eq(2)
      expect(results.map(&:name).sort).to eq(["Alpha", "Beta"])
    end

    it "returns an array of results" do
      results = widget_class.bulk(:retire, where: { status: "active" })
      expect(results).to be_an(Array)
      expect(results.size).to eq(2)
    end

    it "fires events per item" do
      initial_count = app.events.size
      widget_class.bulk(:retire, where: { status: "active" })
      expect(app.events.size - initial_count).to eq(2)
    end

    it "operates on all items when where is empty" do
      results = widget_class.bulk(:retire)
      expect(results.size).to eq(3)
    end

    it "filters by specification when provided" do
      spec_class = Class.new do
        include Hecks::Specification

        def satisfied_by?(widget)
          widget.name == "Alpha"
        end
      end

      results = widget_class.bulk(:retire, where: { status: "active" }, spec: spec_class)
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Alpha")
    end

    it "accepts a spec instance instead of a class" do
      spec_instance = Class.new do
        include Hecks::Specification

        def satisfied_by?(widget)
          widget.name == "Beta"
        end
      end.new

      results = widget_class.bulk(:retire, where: { status: "active" }, spec: spec_instance)
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Beta")
    end
  end
end
