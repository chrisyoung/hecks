require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Hecks.boot with connections" do
  let(:tmpdir) { Dir.mktmpdir("hecks-boot-conn-") }

  after do
    FileUtils.rm_rf(tmpdir)
    mod = Object.const_get("ConnTestDomain") rescue nil
    mod.instance_variable_set(:@connections, nil) if mod&.respond_to?(:connections)
  end

  it "supports extend :memory in boot block" do
    File.write(File.join(tmpdir, "hecks_domain.rb"), <<~RUBY)
      Hecks.domain "ConnTest" do
        aggregate "Item" do
          attribute :name, String
          command "CreateItem" do
            attribute :name, String
          end
        end
      end
    RUBY

    app = Hecks.boot(tmpdir) do
      extend :memory
    end

    mod = Object.const_get("ConnTestDomain")
    expect(mod.connections[:persist][:default]).to eq({ type: :memory })
    expect(app).to be_a(Hecks::Runtime)
  end

  it "supports extend with outbound handler in boot block" do
    File.write(File.join(tmpdir, "hecks_domain.rb"), <<~RUBY)
      Hecks.domain "ConnTest" do
        aggregate "Item" do
          attribute :name, String
          command "CreateItem" do
            attribute :name, String
          end
        end
      end
    RUBY

    received = []
    handler = ->(event) { received << event }

    app = Hecks.boot(tmpdir) do
      extend :audit, handler
    end

    Item.create(name: "Widget")
    expect(received.size).to be >= 1
  end

  it "backward compat: adapter: keyword still works" do
    File.write(File.join(tmpdir, "hecks_domain.rb"), <<~RUBY)
      Hecks.domain "ConnTest" do
        aggregate "Item" do
          attribute :name, String
          command "CreateItem" do
            attribute :name, String
          end
        end
      end
    RUBY

    app = Hecks.boot(tmpdir, adapter: :memory)
    expect(app).to be_a(Hecks::Runtime)
  end
end
