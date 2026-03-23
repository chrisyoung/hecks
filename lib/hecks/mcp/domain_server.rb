# Hecks::MCP::DomainServer
#
# Generates an MCP server from a domain. Every command becomes a tool,
# every query becomes a tool, every aggregate gets find/all/count.
# Boots with memory adapters — zero setup, no database.
#
#   hecks serve:mcp
#
require "mcp"

module Hecks
  module MCP
    class DomainServer
      def initialize(domain)
        @domain = domain
        @server = ::MCP::Server.new(
          name: "#{domain.name} Domain",
          version: Hecks::VERSION
        )
        boot_and_register
      end

      def run
        transport = ::MCP::Transport::Stdio.new(@server)
        transport.open
      end

      private

      def boot_and_register
        build_and_load
        boot_application
        register_command_tools
        register_query_tools
        register_repository_tools
      end

      def build_and_load
        @tmpdir = Dir.mktmpdir("hecks_mcp_domain")
        gem_path = Hecks.build(@domain, output_dir: @tmpdir)
        lib_path = File.join(gem_path, "lib")
        $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
        require @domain.gem_name
        Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
        @mod = Object.const_get(@domain.module_name + "Domain")
      end

      def boot_application
        @app = Services::Application.new(@domain)
        # Bind repository methods so find/all/count work
        @domain.aggregates.each do |agg|
          agg_class = @mod.const_get(agg.name)
          Services::Persistence::RepositoryMethods.bind(agg_class, @app[agg.name])
        end
      end

      def register_command_tools
        @domain.aggregates.each do |agg|
          agg_class = @mod.const_get(agg.name)
          agg.commands.each do |cmd|
            register_command(agg, agg_class, cmd)
          end
        end
      end

      def register_command(agg, agg_class, cmd)
        method_name = derive_method_name(cmd.name, agg.name)
        props = cmd.attributes.each_with_object({}) do |attr, h|
          h[attr.name.to_s] = { type: json_type(attr), description: "#{attr.name} (#{attr.ruby_type})" }
        end
        required = cmd.attributes.map { |a| a.name.to_s }
        klass = agg_class

        @server.define_tool(
          name: cmd.name,
          description: "#{cmd.name} — #{agg.name} action",
          input_schema: { type: "object", properties: props, required: required }
        ) do |args|
          attrs = args.transform_keys(&:to_sym)
          result = klass.send(method_name, **attrs)
          serialize_aggregate(result)
        end
      end

      def register_query_tools
        @domain.aggregates.each do |agg|
          agg_class = @mod.const_get(agg.name)
          agg.queries.each do |query|
            register_query(agg, agg_class, query)
          end
        end
      end

      def register_query(agg, agg_class, query)
        method_name = Hecks::Utils.underscore(query.name).to_sym
        params = query.block.parameters
        klass = agg_class

        if params.empty?
          @server.define_tool(
            name: "#{agg.name}_#{method_name}",
            description: "#{agg.name}.#{method_name} — lookup",
            input_schema: { type: "object", properties: {} }
          ) do |_|
            results = klass.send(method_name)
            results.respond_to?(:map) ? results.map { |r| serialize_aggregate(r) }.join("\n") : results.to_s
          end
        else
          props = params.each_with_object({}) { |(_, name), h| h[name.to_s] = { type: "string" } }
          @server.define_tool(
            name: "#{agg.name}_#{method_name}",
            description: "#{agg.name}.#{method_name} — lookup",
            input_schema: { type: "object", properties: props, required: props.keys }
          ) do |args|
            values = params.map { |_, name| args[name.to_s] }
            results = klass.send(method_name, *values)
            results.respond_to?(:map) ? results.map { |r| serialize_aggregate(r) }.join("\n") : results.to_s
          end
        end
      end

      def register_repository_tools
        @domain.aggregates.each do |agg|
          agg_class = @mod.const_get(agg.name)
          name = agg.name
          klass = agg_class

          @server.define_tool(
            name: "Find#{name}",
            description: "Find a #{name} by ID",
            input_schema: { type: "object", properties: { id: { type: "string" } }, required: ["id"] }
          ) do |args|
            result = klass.find(args["id"])
            result ? serialize_aggregate(result) : "Not found"
          end

          @server.define_tool(
            name: "All#{name}s",
            description: "List all #{name}s",
            input_schema: { type: "object", properties: {} }
          ) do |_|
            klass.all.map { |r| serialize_aggregate(r) }.join("\n")
          end

          @server.define_tool(
            name: "Count#{name}s",
            description: "Count #{name}s",
            input_schema: { type: "object", properties: {} }
          ) do |_|
            klass.count.to_s
          end
        end
      end

      def derive_method_name(cmd_name, agg_name)
        full = Hecks::Utils.underscore(cmd_name)
        snake_agg = Hecks::Utils.underscore(agg_name)
        full.sub(/_#{snake_agg}$/, "").to_sym
      end

      def json_type(attr)
        case attr.ruby_type
        when "Integer" then "integer"
        when "Float" then "number"
        else "string"
        end
      end

      def serialize_aggregate(obj)
        params = obj.class.instance_method(:initialize).parameters
        attrs = params.map do |_, name|
          next unless name && obj.respond_to?(name)
          "#{name}: #{obj.send(name).inspect}"
        end.compact
        "#{obj.class.name.split('::').last}(#{attrs.join(', ')})"
      end
    end
  end
end
