require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Hecks.boot" do
  let(:tmpdir) { Dir.mktmpdir("hecks-boot-") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it "loads a domain and returns a Runtime" do
    File.write(File.join(tmpdir, "Bluebook"), <<~RUBY)
      Hecks.domain "BootTest" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
    RUBY

    app = Hecks.boot(tmpdir)
    expect(app).to be_a(Hecks::Runtime)
    expect(app.domain.name).to eq("BootTest")
  end

  it "raises when Bluebook is missing" do
    expect {
      Hecks.boot(tmpdir)
    }.to raise_error(Hecks::DomainLoadError, /No Bluebook found/)
  end

  it "raises on invalid domains" do
    File.write(File.join(tmpdir, "Bluebook"), <<~RUBY)
      Hecks.domain "BadBoot" do
        aggregate "Order" do
          reference_to "Widget"
          command "PlaceOrder" do
            reference_to "Widget"
          end
        end
      end
    RUBY

    expect {
      Hecks.boot(tmpdir)
    }.to raise_error(Hecks::ValidationError)
  end
end
