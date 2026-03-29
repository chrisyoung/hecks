require "spec_helper"
require "hecks/extensions/logging"

RSpec.describe "HecksLogging connection" do
  before(:all) do
    domain = Hecks.domain "LogTest" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
    @app = Hecks.load(domain)
    Hecks.extension_registry[:logging]&.call(
      Object.const_get("LogTestDomain"), domain, @app
    )
  end

  after do
    Hecks.actor = nil
    Hecks.tenant = nil
  end

  it "logs command name and duration to stdout" do
    output = capture_stdout { Widget.create(name: "Log Test") }
    expect(output).to match(/\[hecks\] CreateWidget \d+\.\d+ms/)
  end

  it "includes actor when set" do
    actor = Struct.new(:role).new("chef")
    Hecks.actor = actor
    output = capture_stdout { Widget.create(name: "Actor Test") }
    expect(output).to include("actor=chef")
  end

  it "includes tenant when set" do
    Hecks.tenant = "acme"
    output = capture_stdout { Widget.create(name: "Tenant Test") }
    expect(output).to include("tenant=acme")
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
