# Hecks::CLI::Domain#build
#
# Validates the domain, assigns a CalVer version, and generates the output.
# Supports multiple targets: ruby (default), static, go, rails.
#
#   hecks domain build [--domain NAME] [--target go|static|rails]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "build", "Generate the domain gem"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      option :target, type: :string, desc: "Build target: ruby (default), static, go, rails"
      option :static, type: :boolean, desc: "Generate static gem (alias for --target static)"
      # Validates the domain definition, assigns a CalVer version, and generates
      # the domain output for the specified target.
      #
      # @return [void]
      def build
        domain = resolve_domain_option
        unless domain
          say "Error: must be run from a directory containing hecks_domain.rb", :red
          raise SystemExit.new(1)
        end
        validator = Validator.new(domain)
        unless validator.valid?
          say "Domain validation failed:", :red
          validator.errors.each { |e| say "  - #{e}", :red }
          return
        end

        target = options[:target] || (options[:static] ? "static" : "ruby")
        versioner = Versioner.new(".")
        version = versioner.next

        case target
        when "go"
          build_go(domain)
        when "static"
          output = Hecks.build_static(domain, version: version)
          say "Built #{domain.gem_name} v#{version} (static)", :green
          say "  Output: #{output}/"
        when "rails"
          say "Rails target not yet implemented (HEC-272)", :yellow
        else
          output = Hecks.build(domain, version: version)
          say "Built #{domain.gem_name} v#{version}", :green
          say "  Docs: #{output}/docs/"
          say "  Output: #{output}/"
        end
      end

      private

      def build_go(domain)
        output = Hecks.build_go(domain, smoke_test: false)
        say "Built #{domain.name} Go project", :green
        say "  Output: #{output}/"

        # Try to compile the Go binary
        if system("which go > /dev/null 2>&1")
          say "  Compiling Go binary..."
          binary = Hecks::Templating::Names.binary_name(domain.name)
          slug = Hecks::Templating::Names.domain_slug(domain.name)
          if system("cd #{output} && go mod tidy 2>&1 && go build -o #{binary} ./cmd/#{slug}/ 2>&1")
            say "  Binary: #{output}/#{binary}", :green
          else
            say "  Go compilation failed — run `go build` manually", :yellow
          end
        else
          say "  Go not installed — run `go build` in #{output}/ to compile", :yellow
        end
      end
    end
  end
end
