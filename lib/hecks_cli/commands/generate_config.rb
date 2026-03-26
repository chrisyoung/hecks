require_relative "../domain_introspector"

# Hecks::CLI::Domain#generate_config
#
# Generates a functional Hecks configuration from the current auto-wiring.
# Extensions self-describe via Hecks.describe_extension so new ones appear
# automatically. Supports single-domain (hecks_domain.rb) and multi-domain
# (hecks_domains/*.rb) projects. Multi-domain configs include listens_to and
# sends_to declarations inferred from reactive policies.
#
#   hecks domain generate:config
#

module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "generate:config", "Generate config reflecting current wiring"
      map "generate:config" => :generate_config
      option :domain, type: :string, desc: "Domain gem name or path"
      option :force, type: :boolean, desc: "Overwrite without prompting"
      # Generates a Hecks configuration file reflecting the current domain wiring.
      #
      # Discovers domains (single or multi), detects available extensions,
      # reports cross-domain connections, and writes the config to app.rb
      # (standalone) or config/initializers/hecks.rb (Rails). Uses
      # ConflictHandler to show diffs if the file already exists.
      #
      # @return [void]
      def generate_config
        detect_extensions

        domains = discover_domains
        return if domains.nil?

        report_discovery(domains)
        config = domains.size == 1 ? build_config(domains.first) : build_multi_config(domains)

        path = rails_app? ? "config/initializers/hecks.rb" : "app.rb"
        content = path == "app.rb" && !File.exist?(path) ? "require \"hecks\"\n\n#{config}" : config
        write_or_diff(path, content)
        say ""
        say config
      end

      private

      # Checks if the current directory is a Rails application.
      #
      # @return [Boolean] true if config/application.rb exists
      def rails_app?
        File.exist?("config/application.rb")
      end

      # Discovers domains from --domain option, hecks_domain.rb, hecks_domains/,
      # or *_domain/ subdirectories.
      #
      # @return [Array<DomainModel::Structure::Domain>, nil] discovered domains,
      #   or nil if none found
      def discover_domains
        if options[:domain]
          domain = resolve_domain(options[:domain])
          return domain ? [domain] : nil
        end

        file = find_domain_file
        return [load_domain(file)] if file

        domains_dir = File.join(Dir.pwd, "hecks_domains")
        if File.directory?(domains_dir)
          files = Dir[File.join(domains_dir, "*.rb")].sort
          return files.map { |f| load_domain(f) } if files.any?
        end

        subdirs = Dir[File.join(Dir.pwd, "*_domain", "hecks_domain.rb")].sort
        return subdirs.map { |f| load_domain(f) } if subdirs.any?

        say "No hecks_domain.rb, hecks_domains/, or *_domain/ found.", :red
        nil
      end

      # Reports discovered domains and cross-domain connections to the console.
      #
      # @param domains [Array<DomainModel::Structure::Domain>] the discovered domains
      # @return [void]
      def report_discovery(domains)
        say "Found #{domains.size} domain#{"s" if domains.size > 1}:", :green
        domains.each { |d| say "  #{d.name}" }

        if domains.size > 1
          intro = DomainIntrospector.new(domains)
          if intro.listeners.any?
            say ""
            say "Cross-domain connections:", :green
            intro.listeners.each do |listener_gem, sources|
              sources.each do |source_gem, policies|
                policies.each do |pol|
                  say "  #{source_gem} -> #{listener_gem} (#{pol.event_name} triggers #{pol.trigger_command})"
                end
              end
            end
          end
        end

        meta = Hecks.extension_meta
        if meta.any?
          say ""
          say "Extensions available:", :green
          meta.each { |name, _| say "  #{name}" }
        end

        say ""
      end

      # Requires all auto-detectable Hecks extensions.
      #
      # @return [void]
      def detect_extensions
        require_relative "../../hecks/load_extensions"
        Hecks::LoadExtensions.require_auto
      end

      # Builds a Hecks.configure block for a single domain.
      #
      # @param domain [DomainModel::Structure::Domain] the domain
      # @return [String] the configuration source code
      def build_config(domain)
        meta = Hecks.extension_meta
        lines = []
        lines << "Hecks.configure do"
        lines << "  domain \"#{domain.gem_name}\""
        lines.concat(adapter_lines)
        lines.concat(auto_wire_lines(meta))
        lines << "end"
        lines.join("\n") + "\n"
      end

      # Builds a Hecks.configure block for multiple domains with cross-domain wiring.
      #
      # @param domains [Array<DomainModel::Structure::Domain>] all domains
      # @return [String] the configuration source code
      def build_multi_config(domains)
        meta = Hecks.extension_meta
        intro = DomainIntrospector.new(domains)

        lines = []
        lines << "Hecks.configure do"
        domains.each { |d| lines.concat(domain_lines(d, intro)) }
        lines.concat(adapter_lines)
        lines.concat(auto_wire_lines(meta))
        lines << "end"
        lines.join("\n") + "\n"
      end

      # Generates adapter configuration lines with commented alternatives.
      #
      # @return [Array<String>] lines for the adapter section
      def adapter_lines
        lines = [""]
        lines << "  adapter :memory"
        lines << "  # adapter :sqlite"
        lines << "  # adapter :postgres"
        lines << ""
        lines
      end

      # Generates domain declaration lines for a single domain in a multi-domain config.
      #
      # Includes sends_to and listens_to declarations if the domain has
      # cross-domain event connections.
      #
      # @param domain [DomainModel::Structure::Domain] the domain
      # @param intro [DomainIntrospector] the introspector with listener/sender maps
      # @return [Array<String>] configuration lines for this domain
      def domain_lines(domain, intro)
        in_deps = intro.listeners[domain.gem_name]
        out_deps = intro.senders[domain.gem_name]
        has_connections = (in_deps && in_deps.any?) || (out_deps && out_deps.any?)

        lines = []
        unless has_connections
          lines << "  domain \"#{domain.gem_name}\""
          return lines
        end

        lines << "  domain \"#{domain.gem_name}\" do"
        if out_deps
          out_deps.each do |target, policies|
            lines << "    sends_to \"#{target}\"  # #{policies.map(&:name).join(", ")}"
          end
        end
        if in_deps
          in_deps.each do |source, policies|
            lines << "    listens_to \"#{source}\"  # #{policies.map(&:name).join(", ")}"
          end
        end
        lines << "  end"
        lines
      end

      # Generates auto_wire and extension configuration lines (commented out).
      #
      # @param meta [Hash] extension metadata from Hecks.extension_meta
      # @return [Array<String>] commented configuration lines
      def auto_wire_lines(meta)
        lines = []
        lines << "  # auto_wire"
        lines << "  # auto_wire except: [:pii]"
        lines << "  # auto_wire only: [:http, :audit]"
        if meta.any?
          lines << ""
          meta.each do |name, m|
            opts = m[:config].map { |k, v| "#{k}: #{v[:default].inspect}" }
            if opts.any?
              lines << "  # extension :#{name}, #{opts.join(", ")}"
            else
              lines << "  # extension :#{name}"
            end
          end
        end
        lines << ""
        lines
      end

    end
  end
end
