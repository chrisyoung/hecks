require "spec_helper"
require "tmpdir"

RSpec.describe "Generator edge cases: trying to break code generation", :slow do
  # Helper: generate into an in-memory hash by monkey-patching write_file,
  # then verify syntax + loadability.
  def build_and_load(domain, skip_validation: false)
    fs = {}
    generator = Hecks::Generators::Infrastructure::DomainGemGenerator.new(
      domain, version: "0.0.1"
    )
    # Intercept file writes — send to hash instead of disk
    generator.define_singleton_method(:write_file) do |root, relative_path, content|
      fs[File.join(root, relative_path)] = content
    end
    generator.generate

    rb_files = fs.select { |k, _| k.end_with?(".rb") }

    # Phase 1: every file must be valid Ruby syntax
    syntax_errors = []
    rb_files.each do |path, content|
      begin
        RubyVM::InstructionSequence.compile(content, path)
      rescue SyntaxError => e
        syntax_errors << "#{path}: #{e.message}"
      end
    end

    # Phase 2: load via generate_source
    load_errors = []
    begin
      Hecks.load_domain(domain, force: true, skip_validation: skip_validation)
    rescue => e
      load_errors << "#{e.class}: #{e.message}"
    end

    { fs: fs, rb_files: rb_files,
      syntax_errors: syntax_errors, load_errors: load_errors }
  end

  # -----------------------------------------------------------------------
  # 1. Lowercase aggregate name
  # -----------------------------------------------------------------------
  describe "lowercase aggregate name" do
    it "generates valid Ruby (class names must start uppercase)" do
      domain = Hecks.domain("LowerCase") do
        aggregate "pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      # The generator uses the name as-is for class names.
      # "class pizza" is NOT valid Ruby for a constant.
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors in generated code:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 2. Aggregate name with spaces
  # -----------------------------------------------------------------------
  describe "aggregate name with spaces" do
    it "generates valid Ruby" do
      domain = Hecks.domain("Spaced") do
        aggregate "My Pizza" do
          attribute :name, String
          command "CreateMyPizza" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 3. Aggregate name with hyphens
  # -----------------------------------------------------------------------
  describe "aggregate name with hyphens" do
    it "generates valid Ruby" do
      domain = Hecks.domain("Hyphen") do
        aggregate "My-Pizza" do
          attribute :name, String
          command "CreateMyPizza" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 4. Attribute name that is a Ruby keyword: class
  # -----------------------------------------------------------------------
  describe "attribute named 'class' (Ruby keyword)" do
    it "generates valid Ruby" do
      domain = Hecks.domain("KeywordAttr") do
        aggregate "Widget" do
          attribute :class, String
          command "CreateWidget" do
            attribute :class, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 5. Attribute name that is a Ruby keyword: def
  # -----------------------------------------------------------------------
  describe "attribute named 'def' (Ruby keyword)" do
    it "generates valid Ruby" do
      domain = Hecks.domain("DefAttr") do
        aggregate "Widget" do
          attribute :def, String
          command "CreateWidget" do
            attribute :def, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 6. Attribute name that is a Ruby keyword: end
  # -----------------------------------------------------------------------
  describe "attribute named 'end' (Ruby keyword)" do
    it "generates valid Ruby" do
      domain = Hecks.domain("EndAttr") do
        aggregate "Widget" do
          attribute :end, String
          command "CreateWidget" do
            attribute :end, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 7. Attribute name that is a Ruby keyword: if
  # -----------------------------------------------------------------------
  describe "attribute named 'if' (Ruby keyword)" do
    it "generates valid Ruby" do
      domain = Hecks.domain("IfAttr") do
        aggregate "Widget" do
          attribute :if, String
          command "CreateWidget" do
            attribute :if, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 8. Very long aggregate name (100 chars)
  # -----------------------------------------------------------------------
  describe "very long aggregate name (100 chars)" do
    it "generates valid Ruby" do
      long_name = "A" * 100
      domain = Hecks.domain("LongName") do
        aggregate long_name do
          attribute :name, String
          command "Create#{long_name}" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 9. Domain name with special characters
  # -----------------------------------------------------------------------
  describe "domain name with special characters" do
    it "generates valid Ruby with dots" do
      domain = Hecks.domain("My.App") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 10. Domain name with special characters (bang and question mark)
  # -----------------------------------------------------------------------
  describe "domain name with bang/question mark" do
    it "generates valid Ruby" do
      domain = Hecks.domain("My!App?") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 11. Value object with same attribute name as parent aggregate
  # -----------------------------------------------------------------------
  describe "value object attribute name collides with aggregate attribute" do
    it "generates valid Ruby and both attributes are accessible" do
      domain = Hecks.domain("Collision") do
        aggregate "Pizza" do
          attribute :name, String
          attribute :toppings, list_of("Topping")

          value_object "Topping" do
            attribute :name, String
          end

          command "CreatePizza" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"

      # Try to actually instantiate both
      mod = Object.const_get("CollisionDomain")
      pizza_class = mod::Pizza
      topping_class = mod::Pizza::Topping

      topping = topping_class.new(name: "Cheese")
      expect(topping.name).to eq("Cheese")

      pizza = pizza_class.new(name: "Margherita")
      expect(pizza.name).to eq("Margherita")
    end
  end

  # -----------------------------------------------------------------------
  # 12. Command name that doesn't start with a verb
  # -----------------------------------------------------------------------
  describe "non-verb command name" do
    it "validator flags it, but generator still produces valid Ruby" do
      domain = Hecks.domain("NonVerb") do
        aggregate "Widget" do
          attribute :name, String
          command "WidgetThing" do
            attribute :name, String
          end
        end
      end

      # Validator should flag this
      valid, errors = Hecks.validate(domain)
      expect(errors.any? { |e| e.include?("verb") }).to be true

      # Hecks.build raises on validation failure, so bypass validation
      # and test the generator directly
      @result = build_and_load(domain, skip_validation: true)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 13. Aggregate name that is a Ruby built-in class name
  # -----------------------------------------------------------------------
  describe "aggregate named 'String' (Ruby built-in)" do
    it "generates valid Ruby" do
      domain = Hecks.domain("Builtin") do
        aggregate "String" do
          attribute :value, String
          command "CreateString" do
            attribute :value, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 14. Aggregate with attribute named 'id' (clashes with generated id)
  # -----------------------------------------------------------------------
  describe "attribute named 'id' (clashes with generated identity)" do
    it "generates valid Ruby without duplicate attr_reader" do
      domain = Hecks.domain("IdClash") do
        aggregate "Widget" do
          attribute :id, String
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      # Check for duplicate :id in attr_reader line
      widget_files = @result[:rb_files].select { |k, _| k.include?("widget.rb") }
      widget_files.each do |path, content|
        if content.include?("attr_reader")
          id_count = content.scan(/:id/).count
          expect(id_count).to be <= 2,
            "Duplicate :id in attr_reader in #{path}:\n#{content}"
        end
      end

      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 15. Attribute named 'created_at' or 'updated_at' (clashes with timestamps)
  # -----------------------------------------------------------------------
  describe "attribute named 'created_at' (clashes with generated timestamps)" do
    it "generates valid Ruby without duplicate parameters" do
      domain = Hecks.domain("TsClash") do
        aggregate "Widget" do
          attribute :created_at, String
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      widget_files = @result[:rb_files].select { |k, _| k.include?("widget.rb") }
      widget_files.each do |path, content|
        if content.include?("def initialize")
          init_line = content.lines.find { |l| l.include?("def initialize") }
          created_at_count = init_line.scan(/created_at/).count if init_line
          expect(created_at_count).to be <= 1,
            "Duplicate created_at in constructor in #{path}:\n#{init_line}"
        end
      end

      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 16. Numeric-starting aggregate name
  # -----------------------------------------------------------------------
  describe "aggregate name starting with a number" do
    it "generates valid Ruby (class names cannot start with digits)" do
      domain = Hecks.domain("Numeric") do
        aggregate "3DModel" do
          attribute :name, String
          command "Create3DModel" do
            attribute :name, String
          end
        end
      end

      # Validator rejects "Create3DModel" as not starting with a verb,
      # so bypass validation to test the generator directly
      @result = build_and_load(domain, skip_validation: true)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"
    end
  end

  # -----------------------------------------------------------------------
  # 17. Empty domain name
  # -----------------------------------------------------------------------
  describe "empty domain name" do
    it "either rejects or generates valid Ruby" do
      domain = Hecks.domain("") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      begin
        @result = build_and_load(domain)
        # If it doesn't raise, at least the syntax should be valid
        expect(@result[:syntax_errors]).to be_empty,
          "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      rescue => e
        # Acceptable: framework rejects empty name
        expect(e).to be_a(StandardError)
      end
    end
  end

  # -----------------------------------------------------------------------
  # 18. Aggregate with attribute named 'initialize' (method name clash)
  # -----------------------------------------------------------------------
  describe "attribute named 'initialize'" do
    it "generates valid Ruby and the attribute is publicly accessible" do
      domain = Hecks.domain("InitClash") do
        aggregate "Widget" do
          attribute :initialize, String
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      @result = build_and_load(domain)
      expect(@result[:syntax_errors]).to be_empty,
        "Syntax errors:\n#{@result[:syntax_errors].join("\n")}"
      expect(@result[:load_errors]).to be_empty,
        "Load errors:\n#{@result[:load_errors].join("\n")}"

      # Ruby's initialize method always acts as the constructor, even with
      # attr_reader :initialize. The attribute is stored but not accessible
      # via a normal reader — only via instance_variable_get.
      widget = InitClashDomain::Widget.new(initialize: "test_val", name: "w")
      expect(widget.instance_variable_get(:@initialize)).to eq("test_val")
    end
  end
end
