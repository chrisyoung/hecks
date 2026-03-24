# Hecks::Generators::Infrastructure::DomainGemGenerator
#
# Generates a complete domain gem on disk — aggregates, value objects, commands,
# events, policies, queries, ports, adapters, specs, and a gemspec. Delegates
# to FileWriter (disk I/O), SourceBuilder (eval-ready string), and SpecWriter
# (RSpec scaffolds). Part of the Generators::Infrastructure layer, invoked by
# the CLI `hecks domain build` command and `Hecks.build`.
#
#   gen = DomainGemGenerator.new(domain, output_dir: "./generated")
#   gen.generate  # => path to generated gem root
#
require "fileutils"
require_relative "domain_gem_generator/file_writer"
require_relative "domain_gem_generator/source_builder"
require_relative "domain_gem_generator/spec_writer"

module Hecks
  module Generators
    module Infrastructure
    class DomainGemGenerator
      include FileWriter
      include SourceBuilder
      include SpecWriter

      def initialize(domain, version: "0.1.0", output_dir: ".")
        @domain = domain
        @version = version
        @output_dir = output_dir
      end

      def generate
        gem_name = @domain.gem_name
        mod = @domain.module_name + "Domain"
        root = File.join(@output_dir, gem_name)

        FileUtils.mkdir_p(root)

        generate_gemspec(root, gem_name, mod)
        generate_entry_point(root, gem_name, mod)
        generate_aggregates(root, gem_name, mod)
        generate_queries(root, gem_name, mod)
        generate_ports(root, gem_name, mod)
        generate_adapters(root, gem_name, mod)
        generate_specs(root, gem_name, mod)
        generate_domain_rb(root)

        root
      end
    end
    end
  end
end
