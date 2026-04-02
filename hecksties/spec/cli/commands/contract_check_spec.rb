# contract_check_spec.rb — HEC-100
#
# Specs for the hecks contract_check CLI command.
#
require "spec_helper"
require "hecks_cli"
require "tmpdir"

RSpec.describe "hecks contract_check" do
  before { allow($stdout).to receive(:puts) }

  it "exits non-zero when no baseline contract exists" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "TestBluebook"), <<~RUBY)
        Hecks.domain "Test" do
          aggregate "Widget" do
            attribute :name, String
            command "CreateWidget" do
              attribute :name, String
            end
          end
        end
      RUBY
      Dir.chdir(dir) do
        cli = Hecks::CLI.new
        allow(cli).to receive(:say)
        expect { cli.contract_check }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end

  it "passes when domain matches saved contract" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "TestBluebook"), <<~RUBY)
        Hecks.domain "Test" do
          aggregate "Widget" do
            attribute :name, String
            command "CreateWidget" do
              attribute :name, String
            end
          end
        end
      RUBY
      Dir.chdir(dir) do
        cli = Hecks::CLI.new
        messages = []
        allow(cli).to receive(:say) { |msg, *| messages << msg }

        # Save baseline
        allow(cli).to receive(:options).and_return({ "save" => true, "domain" => nil })
        cli.contract_check

        # Check against same domain
        allow(cli).to receive(:options).and_return({ "save" => false, "domain" => nil })
        cli.contract_check

        expect(messages.join("\n")).to include("no changes")
      end
    end
  end

  it "exits non-zero on breaking changes" do
    Dir.mktmpdir do |dir|
      # Save baseline with color attribute
      File.write(File.join(dir, "TestBluebook"), <<~RUBY)
        Hecks.domain "Test" do
          aggregate "Widget" do
            attribute :name, String
            attribute :color, String
            command "CreateWidget" do
              attribute :name, String
            end
          end
        end
      RUBY
      Dir.chdir(dir) do
        cli = Hecks::CLI.new
        allow(cli).to receive(:say)
        allow(cli).to receive(:options).and_return({ "save" => true, "domain" => nil })
        cli.contract_check
      end

      # Remove color attribute (breaking change)
      File.write(File.join(dir, "TestBluebook"), <<~RUBY)
        Hecks.domain "Test" do
          aggregate "Widget" do
            attribute :name, String
            command "CreateWidget" do
              attribute :name, String
            end
          end
        end
      RUBY
      Dir.chdir(dir) do
        cli = Hecks::CLI.new
        allow(cli).to receive(:say)
        allow(cli).to receive(:options).and_return({ "save" => false, "domain" => nil })
        expect { cli.contract_check }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end
end
