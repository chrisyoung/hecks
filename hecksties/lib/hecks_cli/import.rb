require_relative "import/schema_parser"
require_relative "import/model_parser"
require_relative "import/domain_assembler"
require_relative "import/model_only_assembler"
require_relative "import/ruby_parser"
require_relative "import/ruby_assembler"

module Hecks
  # Hecks::Import
  #
  # Reverse-engineers existing projects into Hecks domain definitions.
  # Supports Rails apps (via schema.rb + models), Rails model-only
  # projects, and any plain Ruby project (POROs, Structs, Data classes).
  #
  #   Hecks::Import.from_rails("/path/to/rails/app")
  #   Hecks::Import.from_ruby("/path/to/ruby/lib")
  #   Hecks::Import.from_directory("/path/to/project")  # auto-detects
  #
  module Import
    def self.from_rails(app_path, domain_name: nil)
      schema_path = File.join(app_path, "db", "schema.rb")
      models_dir  = File.join(app_path, "app", "models")
      domain_name ||= infer_domain_name(app_path)

      schema_data = SchemaParser.new(schema_path).parse
      model_data  = File.directory?(models_dir) ? ModelParser.new(models_dir).parse : {}
      DomainAssembler.new(schema_data, model_data, domain_name: domain_name).assemble
    end

    def self.from_schema(schema_path, domain_name: "MyDomain")
      schema_data = SchemaParser.new(schema_path).parse
      DomainAssembler.new(schema_data, {}, domain_name: domain_name).assemble
    end

    def self.from_ruby(path, domain_name: nil)
      domain_name ||= infer_domain_name(path)
      parsed = RubyParser.new(path).parse
      RubyAssembler.new(parsed, domain_name: domain_name).assemble
    end

    def self.from_directory(path, domain_name: nil)
      domain_name ||= infer_domain_name(path)

      if rails_project?(path)
        from_rails(path, domain_name: domain_name)
      elsif rails_models?(path)
        models_dir = detect_models_dir(path)
        from_models(models_dir, domain_name: domain_name)
      else
        ruby_dir = detect_ruby_dir(path)
        from_ruby(ruby_dir, domain_name: domain_name)
      end
    end

    def self.from_models(models_dir, domain_name: "MyDomain")
      model_data = ModelParser.new(models_dir).parse
      ModelOnlyAssembler.new(model_data, domain_name: domain_name).assemble
    end

    def self.rails_project?(path)
      File.exist?(File.join(path, "db", "schema.rb"))
    end

    def self.rails_models?(path)
      detect_models_dir(path) != path ||
        Dir[File.join(path, "**", "*.rb")].any? { |f| File.read(f).include?("ApplicationRecord") }
    end

    def self.detect_models_dir(path)
      candidates = [
        File.join(path, "app", "models"),
        File.join(path, "models"),
        path
      ]
      candidates.find { |d| File.directory?(d) } || path
    end

    def self.detect_ruby_dir(path)
      lib_dir = File.join(path, "lib")
      File.directory?(lib_dir) ? lib_dir : path
    end

    def self.infer_domain_name(path)
      Hecks::Utils.sanitize_constant(File.basename(File.expand_path(path)))
    end

    private_class_method :detect_models_dir, :detect_ruby_dir, :infer_domain_name
  end
end
