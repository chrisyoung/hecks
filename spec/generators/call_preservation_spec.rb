require "spec_helper"
require "tmpdir"

RSpec.describe "Call method preservation" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String

        command "CreatePizza" do
          attribute :name, String
          attribute :description, String
        end
      end
    end
  end

  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  let(:generator) { Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain, output_dir: tmpdir) }
  let(:gem_root) { File.join(tmpdir, "pizzas_domain") }
  let(:cmd_path) { File.join(gem_root, "lib/pizzas_domain/pizza/commands/create_pizza.rb") }

  context "when regenerating preserves a custom call body" do
    it "keeps the hand-edited call method" do
      generator.generate

      # Inject a custom call method into the generated file
      original = File.read(cmd_path)
      custom_call = <<~RUBY.chomp
        def call
              validate_name!(name)
              Pizza.new(name: name, description: description)
            end
      RUBY
      generated_call = Hecks::Utils.extract_call_method(original)
      modified = original.sub(generated_call, "        " + custom_call)
      File.write(cmd_path, modified)

      # Regenerate
      generator.generate

      result = File.read(cmd_path)
      expect(result).to include("validate_name!(name)")
      expect(result).to include("Pizza.new(name: name, description: description)")
    end
  end

  context "when regenerating updates attributes when DSL changes" do
    it "updates attr_reader and initializer" do
      generator.generate

      # Rebuild with an extra attribute
      new_domain = Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String
          attribute :description, String
          attribute :price, Integer

          command "CreatePizza" do
            attribute :name, String
            attribute :description, String
            attribute :price, Integer
          end
        end
      end

      new_gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(new_domain, output_dir: tmpdir)
      new_gen.generate

      result = File.read(cmd_path)
      expect(result).to include(":price")
    end
  end

  context "when a brand new command is generated" do
    it "gets the auto-generated call body" do
      generator.generate

      result = File.read(cmd_path)
      expect(result).to include("def call")
      expect(result).to include("Pizza.new")
    end
  end

  context "when the existing file has the default call body" do
    it "overwrites with the new default" do
      generator.generate

      original = File.read(cmd_path)

      # Regenerate without changes — should produce identical output
      generator.generate

      result = File.read(cmd_path)
      expect(result).to eq(original)
    end
  end

  context "when the DSL defines a call_body" do
    let(:domain_with_call) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String

          command "CreatePizza" do
            attribute :name, String
            call do
              Pizza.new(name: name.upcase)
            end
          end
        end
      end
    end

    it "always uses the DSL version over existing custom code" do
      # First generate with a custom call on disk
      generator.generate

      # Write a hand-edited call method
      original = File.read(cmd_path)
      generated_call = Hecks::Utils.extract_call_method(original)
      custom = original.sub(generated_call, "        def call\n          raise 'custom'\n        end")
      File.write(cmd_path, custom)

      # Now regenerate with DSL call_body — DSL should win
      dsl_gen = Hecks::Generators::Infrastructure::DomainGemGenerator.new(domain_with_call, output_dir: tmpdir)
      dsl_gen.generate

      result = File.read(cmd_path)
      expect(result).to include("name.upcase")
      expect(result).not_to include("raise 'custom'")
    end
  end
end

RSpec.describe "Hecks::Utils.extract_call_method" do
  it "extracts a simple call method" do
    source = <<~RUBY
      class Foo
        def call
          Pizza.new(name: name)
        end
      end
    RUBY
    result = Hecks::Utils.extract_call_method(source)
    expect(result).to include("def call")
    expect(result).to include("Pizza.new(name: name)")
    expect(result).to include("end")
  end

  it "handles nested blocks" do
    source = <<~RUBY
      class Foo
        def call
          if valid?
            Pizza.new(name: name)
          end
        end
      end
    RUBY
    result = Hecks::Utils.extract_call_method(source)
    expect(result).to include("if valid?")
    expect(result).to include("Pizza.new(name: name)")
    expect(result.scan("end").size).to eq(2)
  end

  it "returns nil when no call method exists" do
    source = "class Foo; def bar; end; end"
    result = Hecks::Utils.extract_call_method(source)
    expect(result).to be_nil
  end

  it "returns nil for nil input" do
    expect(Hecks::Utils.extract_call_method(nil)).to be_nil
  end
end
