# Hecks::MCP::DomainServer
#
# Generates an MCP server from a domain. Every command becomes a tool,
# every query becomes a tool, every aggregate gets find/all/count.
# Boots with memory adapters — zero setup, no database.
#
# Tool registration is split into three mixins:
#   CommandTools, QueryTools, RepositoryTools
#
#   hecks domain mcp --domain NAME
#
require "mcp"
require "tmpdir"

require_relative "domain_server/command_tools"
require_relative "domain_server/query_tools"
require_relative "domain_server/repository_tools"

module Hecks
  module MCP
    class DomainServer
      include CommandTools
      include QueryTools
      include RepositoryTools

      def initialize(domain)
        @domain = domain
        @server = ::MCP::Server.new(
          name: "#{domain.name} Domain",
          version: Hecks::VERSION
        )
        boot_and_register
      end

      def run
        require "mcp/server/transports/stdio_transport"
        ::MCP::Server::Transports::StdioTransport.new(@server).open
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
        mod_name = @domain.module_name + "Domain"
        if Object.const_defined?(mod_name)
          @mod = Object.const_get(mod_name)
        else
          @tmpdir = Dir.mktmpdir("hecks_mcp_domain")
          gem_path = Hecks.build(@domain, output_dir: @tmpdir)
          lib_path = File.join(gem_path, "lib")
          $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
          require @domain.gem_name
          Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| require f }
          @mod = Object.const_get(mod_name)
        end
      end

      def boot_application
        @app = Services::Runtime.new(@domain)
        @domain.aggregates.each do |agg|
          agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
          Services::Persistence::RepositoryMethods.bind(agg_class, @app[agg.name])
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
        attrs = Hecks::Utils.object_attr_names(obj).map do |name|
          next unless obj.respond_to?(name)
          "#{name}: #{obj.send(name).inspect}"
        end.compact
        "#{obj.class.name.split('::').last}(#{attrs.join(', ')})"
      end
    end
  end
end
