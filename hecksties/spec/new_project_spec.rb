require "spec_helper"
require "fileutils"
require "tmpdir"
require "stringio"
require "hecks_cli"

RSpec.describe "hecks new CLI command" do
  let(:tmpdir) { Dir.mktmpdir("hecks-new-") }
  after { FileUtils.rm_rf(tmpdir) }

  def with_stdin(text)
    fake = StringIO.new(text)
    allow(fake).to receive(:tty?).and_return(true)
    original = $stdin
    $stdin = fake
    yield
  ensure
    $stdin = original
  end

  it "generates project files" do
    Dir.chdir(tmpdir) do
      cli = Hecks::CLI.new
      cli.invoke(:new_project, ["my_app"], { "no-world-goals": true })

      expect(Dir["my_app/*Bluebook"].any?).to be true
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
      cli.invoke(:new_project, ["my_cool_app"], { "no-world-goals": true })

      bluebook = Dir["my_cool_app/*Bluebook"].first
      content = File.read(bluebook)
      expect(content).to include('"MyCoolApp"')
    end
  end

  it "refuses to overwrite an existing directory" do
    Dir.chdir(tmpdir) do
      FileUtils.mkdir_p("existing")
      cli = Hecks::CLI.new
      expect {
        cli.invoke(:new_project, ["existing"], { "no-world-goals": true })
      }.not_to raise_error
      expect(File.exist?("existing/app.rb")).to be false
    end
  end

  it "generates a valid domain that can be booted" do
    Dir.chdir(tmpdir) do
      cli = Hecks::CLI.new
      cli.invoke(:new_project, ["bootable"], { "no-world-goals": true })
    end

    bluebook = Dir[File.join(tmpdir, "bootable/*Bluebook")].first
    domain_content = File.read(bluebook)
    domain = eval(domain_content, TOPLEVEL_BINDING, bluebook, 1)
    valid, errors = Hecks.validate(domain)
    expect(valid).to be(true), "Generated domain is invalid: #{errors.join(', ')}"
  end

  context "world goals onboarding" do
    it "skips prompt with --no-world-goals flag and generates domain without world_concerns" do
      Dir.chdir(tmpdir) do
        Hecks::CLI.new.invoke(:new_project, ["ci_app"], { "no-world-goals": true })

        bluebook = File.read(Dir["ci_app/*Bluebook"].first)
        expect(bluebook).not_to include("world_concerns")
      end
    end

    it "skips prompt in non-interactive mode" do
      allow($stdin).to receive(:tty?).and_return(false)

      Dir.chdir(tmpdir) do
        Hecks::CLI.new.invoke(:new_project, ["noninteractive"])

        bluebook = File.read(Dir["noninteractive/*Bluebook"].first)
        expect(bluebook).not_to include("world_concerns")
      end
    end

    it "choice 2: generates domain without world_concerns" do
      Dir.chdir(tmpdir) do
        with_stdin("2\n") do
          Hecks::CLI.new.invoke(:new_project, ["skip_app"])
        end
        bluebook = File.read(Dir["skip_app/*Bluebook"].first)
        expect(bluebook).not_to include("world_concerns")
      end
    end

    it "choice 3: generates domain with commented stub" do
      Dir.chdir(tmpdir) do
        with_stdin("3\n") do
          Hecks::CLI.new.invoke(:new_project, ["na_app"])
        end
        bluebook = File.read(Dir["na_app/*Bluebook"].first)
        expect(bluebook).to include("# world_concerns :transparency, :consent  # add when ready")
      end
    end

    it "choice 1 with goals: generates domain with world_concerns" do
      Dir.chdir(tmpdir) do
        with_stdin("1\nprivacy, consent\n") do
          Hecks::CLI.new.invoke(:new_project, ["goals_app"])
        end
        bluebook = File.read(Dir["goals_app/*Bluebook"].first)
        expect(bluebook).to include("world_concerns :privacy, :consent")
      end
    end

    it "choice 1 with invalid goals: silently skips invalid ones" do
      Dir.chdir(tmpdir) do
        with_stdin("1\nprivacy, bogus, consent\n") do
          Hecks::CLI.new.invoke(:new_project, ["filter_app"])
        end
        bluebook = File.read(Dir["filter_app/*Bluebook"].first)
        expect(bluebook).to include("world_concerns :privacy, :consent")
        expect(bluebook).not_to include("bogus")
      end
    end

    it "choice 1 with no goals entered: generates domain without world_concerns" do
      Dir.chdir(tmpdir) do
        with_stdin("1\n\n") do
          Hecks::CLI.new.invoke(:new_project, ["empty_goals_app"])
        end
        bluebook = File.read(Dir["empty_goals_app/*Bluebook"].first)
        expect(bluebook).not_to include("world_concerns")
      end
    end
  end
end
