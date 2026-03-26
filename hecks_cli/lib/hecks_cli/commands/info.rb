# Hecks::CLI::Domain#info
#
# Shows what Hecks.boot would auto-discover and wire: domains, aggregates,
# extensions, services, cross-domain policies, and event subscriptions.
# Reads domains/ directory for multi-domain, hecks_domain.rb for single.
#
#   hecks domain info
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "info", "Show auto-wiring details for this project"
      # Displays auto-wiring details for the current project.
      #
      # Shows all discovered domains with their aggregates, available
      # extensions, local services, and cross-domain reactive policies
      # with event flow direction.
      #
      # @return [void]
      def info
        domains = load_all_domains
        return if domains.empty?

        say_domains(domains)
        say_extensions
        say_services
        say_cross_domain_policies(domains)
      end

      private

      # Loads all domains from domains/ directory or hecks_domain.rb.
      #
      # @return [Array<DomainModel::Structure::Domain>] loaded domains,
      #   or empty array if none found
      def load_all_domains
        domains_dir = File.join(Dir.pwd, "domains")
        if File.directory?(domains_dir)
          Dir[File.join(domains_dir, "*.rb")].sort.map do |path|
            eval(File.read(path), nil, path, 1)
          end
        elsif File.exist?(File.join(Dir.pwd, "hecks_domain.rb"))
          [load_domain(File.join(Dir.pwd, "hecks_domain.rb"))]
        else
          say "No domains/ directory or hecks_domain.rb found", :red
          []
        end
      end

      # Prints all discovered domains with their aggregate names.
      #
      # @param domains [Array<DomainModel::Structure::Domain>] the domains
      # @return [void]
      def say_domains(domains)
        say "Domains (#{domains.size}):", :green
        domains.each do |d|
          aggs = d.aggregates.map(&:name).join(", ")
          say "  #{d.name.ljust(20)} — #{aggs}"
        end
        say ""
      end

      # Prints available Hecks extensions detected from the environment.
      #
      # @return [void]
      def say_extensions
        ext_dir = File.join(Dir.pwd, "Gemfile")
        available = []
        require "hecks/runtime/load_extensions"
        Hecks::LoadExtensions::AUTO.each do |name|
          Hecks::LoadExtensions.require_if_available(name)
          available << name.to_s if Hecks.extension_registry.key?(name)
        end
        return if available.empty?
        say "Extensions:", :green
        available.each { |e| say "  #{e}" }
        say ""
      end

      # Prints local services found in the services/ directory.
      #
      # @return [void]
      def say_services
        svc_dir = File.join(Dir.pwd, "services")
        return unless File.directory?(svc_dir)
        files = Dir[File.join(svc_dir, "*.rb")].sort
        return if files.empty?
        say "Services (#{files.size}):", :green
        files.each do |f|
          name = File.basename(f, ".rb").split("_").map(&:capitalize).join
          say "  #{name}"
        end
        say ""
      end

      # Prints cross-domain reactive policies with event flow direction.
      #
      # For each reactive policy, shows the event name, triggered command,
      # source domain, target domain, and whether it is conditional.
      #
      # @param domains [Array<DomainModel::Structure::Domain>] all domains
      # @return [void]
      def say_cross_domain_policies(domains)
        policies = []
        domains.each do |d|
          d.aggregates.each do |agg|
            agg.policies.select(&:reactive?).each do |p|
              source = find_event_source(domains, p.event_name)
              target = find_command_target(domains, p.trigger_command)
              policies << { name: p.name, event: p.event_name,
                            trigger: p.trigger_command,
                            from: source, to: target,
                            conditional: !!p.condition }
            end
          end
          d.policies.select(&:reactive?).each do |p|
            source = find_event_source(domains, p.event_name)
            target = find_command_target(domains, p.trigger_command)
            policies << { name: p.name, event: p.event_name,
                          trigger: p.trigger_command,
                          from: source, to: target,
                          conditional: !!p.condition }
          end
        end
        return if policies.empty?
        say "Cross-domain events:", :green
        policies.each do |p|
          cond = p[:conditional] ? " (conditional)" : ""
          say "  #{p[:event].ljust(25)} → #{p[:trigger].ljust(20)} (#{p[:from]} → #{p[:to]})#{cond}"
        end
      end

      # Finds which domain produces a given event.
      #
      # @param domains [Array<DomainModel::Structure::Domain>] all domains
      # @param event_name [String] the event name to search for
      # @return [String] the domain name, or "?" if not found
      def find_event_source(domains, event_name)
        domains.each do |d|
          d.aggregates.each do |a|
            return d.name if a.events.any? { |e| e.name == event_name }
          end
        end
        "?"
      end

      # Finds which domain owns a given command.
      #
      # @param domains [Array<DomainModel::Structure::Domain>] all domains
      # @param command_name [String] the command name to search for
      # @return [String] the domain name, or "?" if not found
      def find_command_target(domains, command_name)
        domains.each do |d|
          d.aggregates.each do |a|
            return d.name if a.commands.any? { |c| c.name == command_name }
          end
        end
        "?"
      end
    end
  end
end
