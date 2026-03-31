require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "hecks new CLI command" do
  let(:tmpdir) { Dir.mktmpdir("hecks-new-") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  it "generates project files" do
    Dir.chdir(tmpdir) do
      cli = Hecks::CLI.new
      cli.invoke(:new_project, ["my_app"])

      expect(File.exist?("my_app/Bluebook")).to be true
      expect(File.exist?("my_app/app.rb")).to be true
      expect(File.exist?("my_app/Gemfile")).to be true
      expect(File.exist?("my_app/spec/spec_helper.rb")).to be true
      expect(File.exist?("my_app/.gitignore")).to be true
      expect(File.exist?("my_app/.rspec")).to be true
    end
  end

  it "uses PascalCase for the domain name" do
    Dir.chdir(tmpdir) do
      cli = Hecks::CLI.new
      cli.invoke(:new_project, ["my_cool_app"])

      content = File.read("my_cool_app/Bluebook")
      expect(content).to include('"MyCoolApp"')
    end
  end

  it "refuses to overwrite an existing directory" do
    Dir.chdir(tmpdir) do
      FileUtils.mkdir_p("existing")
      cli = Hecks::CLI.new
      expect {
        cli.invoke(:new_project, ["existing"])
      }.not_to raise_error
      # Should not create files inside existing directory
      expect(File.exist?("existing/app.rb")).to be false
    end
  end

  it "generates a valid domain that can be booted" do
    Dir.chdir(tmpdir) do
      cli = Hecks::CLI.new
      cli.invoke(:new_project, ["bootable"])
    end

    domain_content = File.read(File.join(tmpdir, "bootable/Bluebook"))
    domain = eval(domain_content, TOPLEVEL_BINDING, "bootable/Bluebook", 1)
    valid, errors = Hecks.validate(domain)
    expect(valid).to be true
  end
end
