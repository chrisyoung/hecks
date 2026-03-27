# HecksStandalone::EntryPointGenerator
#
# Generates two files for the standalone domain:
# 1. lib/<gem>.rb — autoloads and constants (regeneratable)
# 2. lib/<gem>/boot.rb — wiring, boot method, serve (stable)
#
# The entry point requires boot.rb and auto-boots. Regenerating the
# domain files doesn't touch boot.rb, so the running server picks up
# changes via live reload.
#
module HecksStandalone
  class EntryPointGenerator
    def initialize(domain)
      @domain = domain
    end

    # The main entry point — autoloads + constants. Regeneratable.
    def generate_entry_point(mod, gem_name)
      @gem_name = gem_name
      lines = []
      lines << "require \"securerandom\""
      lines << "require_relative \"#{gem_name}/runtime/errors\""
      lines << ""
      lines << "module #{mod}"
      lines.concat(runtime_autoloads(gem_name))
      lines.concat(aggregate_autoloads(gem_name))
      lines.concat(port_autoloads(gem_name))
      lines.concat(adapter_autoloads(gem_name))
      lines << ""
      lines.concat(constants)
      lines << "end"
      lines << ""
      lines << "require_relative \"../boot\""
      lines << "#{mod}.boot unless ENV[\"HECKS_SKIP_BOOT\"]"
      lines.join("\n") + "\n"
    end

    # The boot file — wiring, serve, roles. Written once, not regenerated.
    def generate_boot(mod, gem_name)
      @gem_name = gem_name
      lines = []
      lines << "module #{mod}"
      lines.concat(boot_method(mod))
      lines << "end"
      lines.join("\n") + "\n"
    end

    private

    def runtime_autoloads(gem_name)
      lines = ["  module Runtime"]
      %w[operators event_bus command_bus query_builder model command query specification].each do |f|
        const = f.split("_").map(&:capitalize).join
        lines << "    autoload :#{const}, \"#{gem_name}/runtime/#{f}\""
      end
      lines << "  end"
      lines << ""
      lines
    end

    def aggregate_autoloads(gem_name)
      @domain.aggregates.map do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        "  autoload :#{safe}, \"#{gem_name}/#{snake}/#{snake}\""
      end
    end

    def port_autoloads(gem_name)
      lines = ["", "  module Ports"]
      @domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        lines << "    autoload :#{safe}Repository, \"#{gem_name}/ports/#{snake}_repository\""
      end
      lines << "  end"
      lines
    end

    def adapter_autoloads(gem_name)
      lines = ["", "  module Adapters"]
      @domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        lines << "    autoload :#{safe}MemoryRepository, \"#{gem_name}/adapters/#{snake}_memory_repository\""
      end
      lines << "  end"
      lines
    end

    def constants
      all_roles = @domain.aggregates.flat_map { |a| a.ports.keys }.uniq.map(&:to_s)
      all_roles = ["admin"] if all_roles.empty?

      port_map = {}
      @domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        agg.ports.each do |role_name, port_def|
          port_map[role_name.to_s] ||= {}
          port_map[role_name.to_s][safe] = port_def.allowed_methods.map(&:to_s)
        end
      end

      [
        "  ROLES = #{all_roles.inspect}.freeze",
        "  PORTS = #{port_map.inspect}.freeze",
        "  VALIDATIONS = #{build_validation_rules.inspect}.freeze"
      ]
    end

    def boot_method(mod)
      all_roles = @domain.aggregates.flat_map { |a| a.ports.keys }.uniq.map(&:to_s)
      all_roles = ["admin"] if all_roles.empty?

      lines = []
      lines << "  class << self"
      lines << "    attr_accessor :event_bus, :command_bus, :current_role"
      lines << "    attr_reader :config"
      lines << ""
      lines << "    def role_allows?(aggregate, action)"
      lines << "      return true unless current_role"
      lines << "      allowed = PORTS.dig(current_role.to_s, aggregate.to_s)"
      lines << "      return true unless allowed"
      lines << "      allowed.include?(action.to_s)"
      lines << "    end"
      lines << ""
      lines << "    def boot(adapter: :memory)"
      lines << "      @current_role ||= \"#{all_roles.first}\""
      lines << "      @config = { adapter: adapter, booted_at: Time.now }"
      lines << "      @event_bus = Runtime::EventBus.new"
      lines << "      @command_bus = Runtime::CommandBus.new(event_bus: @event_bus)"
      lines << "      require_relative \"lib/#{@gem_name}/validations\""
      lines << "      Validations.rules = VALIDATIONS"
      lines << ""
      @domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        lines << "      #{safe}.repository = Adapters::#{safe}MemoryRepository.new"
        lines << "      #{safe}.event_bus = @event_bus"
        lines << "      #{safe}.command_bus = @command_bus"
      end
      lines << ""
      @domain.aggregates.each { |agg| wire_commands(lines, agg) }
      @domain.aggregates.each { |agg| wire_queries(lines, agg) }
      @domain.aggregates.each { |agg| wire_persistence(lines, agg) }
      wire_policies(lines)
      lines << ""
      @domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        lines << "      Object.const_set(:#{safe}, #{safe}) unless Object.const_defined?(:#{safe})"
      end
      lines << "      self"
      lines << "    end"
      lines << ""
      lines << "    def reboot(adapter: :memory)"
      lines << "      boot(adapter: adapter)"
      lines << "    end"
      lines << ""
      lines << "    def on(event_name, &block)"
      lines << "      @event_bus.subscribe(event_name, &block)"
      lines << "    end"
      lines << ""
      lines << "    def events"
      lines << "      @event_bus.events"
      lines << "    end"
      lines << ""
      lines << "    def serve(port: 9292)"
      lines << "      require_relative \"lib/#{@gem_name}/server/domain_app\""
      lines << "      Server::DomainApp.new(self).start(port: port)"
      lines << "    end"
      lines << ""
      lines << "    def domain_info"
      lines << "      {"
      agg_infos = @domain.aggregates.map do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        cmds = agg.commands.map(&:name).inspect
        ports_hash = agg.ports.values.map { |p| "#{p.name.inspect} => #{p.allowed_methods.map(&:to_s).inspect}" }.join(", ")
        "        #{safe.inspect} => { commands: #{cmds}, ports: { #{ports_hash} }, count: #{safe}.count }"
      end
      lines << agg_infos.join(",\n")
      lines << "      }"
      lines << "    end"
      policy_names = (@domain.aggregates.flat_map { |a| a.policies.map { |p| "#{p.event_name} -> #{p.name}" } } +
                      @domain.policies.map { |p| "#{p.event_name} -> #{p.trigger_command}" }).inspect
      lines << ""
      lines << "    def policy_info"
      lines << "      #{policy_names}"
      lines << "    end"
      lines << "  end"
      lines
    end

    def wire_commands(lines, agg)
      safe = Hecks::Utils.sanitize_constant(agg.name)
      agg.commands.each do |cmd|
        method_name = Hecks::Utils.underscore(cmd.name)
        lines << "      #{safe}::Commands::#{cmd.name}.repository = #{safe}.repository"
        lines << "      #{safe}::Commands::#{cmd.name}.event_bus = @event_bus"
        lines << "      #{safe}::Commands::#{cmd.name}.command_bus = @command_bus"
        lines << "      #{safe}::Commands::#{cmd.name}.aggregate_type = \"#{safe}\""
        lines << "      #{safe}.define_singleton_method(:#{method_name}) { |**attrs| #{safe}::Commands::#{cmd.name}.call(**attrs) }"
      end
    end

    def wire_queries(lines, agg)
      safe = Hecks::Utils.sanitize_constant(agg.name)
      agg.queries.each do |q|
        method_name = Hecks::Utils.underscore(q.name)
        lines << "      #{safe}::Queries::#{q.name}.repository = #{safe}.repository"
        lines << "      #{safe}.define_singleton_method(:#{method_name}) { |*args| #{safe}::Queries::#{q.name}.call(*args) }"
      end
    end

    def wire_persistence(lines, agg)
      safe = Hecks::Utils.sanitize_constant(agg.name)
      lines << "      #{safe}.define_singleton_method(:find) { |id| repository.find(id) }"
      lines << "      #{safe}.define_singleton_method(:all) { repository.all }"
      lines << "      #{safe}.define_singleton_method(:count) { repository.count }"
      lines << "      #{safe}.define_singleton_method(:where) { |**conds| Runtime::QueryBuilder.new(repository).where(**conds) }"
    end

    def wire_policies(lines)
      @domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        agg.policies.each do |pol|
          next if pol.guard?
          lines << "      @event_bus.subscribe(\"#{pol.event_name}\") { |event| #{safe}::Policies::#{pol.name}.new.call(event) }"
        end
      end
      @domain.policies.each do |pol|
        trigger_agg = @domain.aggregates.find { |a| a.commands.any? { |c| c.name == pol.trigger_command } }
        next unless trigger_agg
        safe = Hecks::Utils.sanitize_constant(trigger_agg.name)
        if pol.attribute_map && !pol.attribute_map.empty?
          args = pol.attribute_map.map { |to, from| "#{to}: event.#{from}" }.join(", ")
          lines << "      @event_bus.subscribe(\"#{pol.event_name}\") { |event| #{safe}::Commands::#{pol.trigger_command}.call(#{args}) }"
        else
          lines << "      @event_bus.subscribe(\"#{pol.event_name}\") { |event| #{safe}::Commands::#{pol.trigger_command}.call }"
        end
      end
    end

    def build_validation_rules
      rules = {}
      @domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        agg.commands.each do |cmd|
          cmd_snake = Hecks::Utils.underscore(cmd.name)
          cmd_rules = {}
          cmd.attributes.each do |attr|
            v = agg.validations.find { |val| val.field.to_s == attr.name.to_s }
            if v
              cmd_rules[attr.name.to_s] = v.rules.transform_keys(&:to_s)
              next
            end
            agg.value_objects.each do |vo|
              vo_attr = vo.attributes.find { |va| va.name.to_s == attr.name.to_s }
              if vo_attr
                r = { "presence" => true }
                vo.invariants.each do |inv|
                  r["positive"] = true if inv.message.to_s =~ /#{attr.name}.*positive|#{attr.name}.*> ?0/i
                end
                cmd_rules[attr.name.to_s] = r
              end
            end
          end
          rules["#{safe}/#{cmd_snake}"] = cmd_rules unless cmd_rules.empty?
        end
      end
      rules
    end
  end
end
