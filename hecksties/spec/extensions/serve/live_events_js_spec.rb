require "spec_helper"
require "hecks/extensions/serve/live_events_js"

RSpec.describe Hecks::HTTP::LiveEventsJs do
  describe ".style_tag" do
    it "returns a style tag with live event CSS" do
      css = described_class.style_tag
      expect(css).to include("<style>")
      expect(css).to include(".hecks-live")
      expect(css).to include(".hecks-live-toggle")
      expect(css).to include(".hecks-live-panel")
    end
  end

  describe ".script_tag" do
    it "returns a script tag with HecksLiveEvents class" do
      js = described_class.script_tag
      expect(js).to include("<script>")
      expect(js).to include("HecksLiveEvents")
      expect(js).to include("EventSource")
      expect(js).to include("/_live")
    end

    it "includes disconnect method" do
      js = described_class.script_tag
      expect(js).to include("disconnect")
    end

    it "includes maxEvents config" do
      js = described_class.script_tag
      expect(js).to include("maxEvents")
    end
  end

  describe ".indicator_html" do
    it "returns HTML with toggle button and panel" do
      html = described_class.indicator_html
      expect(html).to include("hecks-live-toggle")
      expect(html).to include("hecks-live-panel")
      expect(html).to include("Live")
    end
  end
end
