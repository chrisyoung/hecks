# Hecks::CLI::Domain#serve
#
# Serves a domain over HTTP. By default starts a REST + SSE server via
# HTTP::DomainServer. With --rpc, starts a JSON-RPC server via HTTP::RpcServer.
# With --static, builds a static gem and serves with the built-in UI.
#
#   hecks domain serve [--domain NAME] [--port 9292] [--rpc] [--static]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "serve", "Serve a domain as HTTP (default) or JSON-RPC (--rpc)"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      option :port, type: :numeric, default: 9292, desc: "HTTP port"
      option :rpc, type: :boolean, default: false, desc: "JSON-RPC"
      option :live, type: :boolean, default: false, desc: "WebSocket server"
      option :live_port, type: :numeric, default: 9293, desc: "WebSocket port"
      option :static, type: :boolean, default: false, desc: "Serve with static UI"
      # Starts an HTTP server for the domain.
      #
      # @return [void] runs until interrupted
      def serve
        domain = resolve_domain_option
        return unless domain
        if options[:static]
          serve_static(domain, options[:port])
        elsif options[:rpc]
          require "hecks_serve"
          HTTP::RpcServer.new(domain, port: options[:port]).run
        else
          require "hecks_serve"
          server = HTTP::DomainServer.new(domain, port: options[:port],
            live: options[:live], live_port: options[:live_port])
          server.run
        end
      end

      private

      def serve_static(domain, port)
        require "tmpdir"
        dir = Dir.mktmpdir("hecks-serve-")
        output = Hecks.build_static(domain, output_dir: dir)
        lib_path = File.join(output, "lib")
        $LOAD_PATH.unshift(lib_path)
        gem_name = domain.gem_name
        require gem_name
        mod = Object.const_get(domain.module_name + "Domain")
        say "Serving #{mod.name} (static) on http://localhost:#{port}", :green
        mod.serve(port: port)
      ensure
        FileUtils.rm_rf(dir) if dir && Dir.exist?(dir)
      end
    end
  end
end
