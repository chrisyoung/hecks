
# Hecks::CLI::Domain#serve
#
# Serves a domain over HTTP. Supports single-domain and multi-domain
# (hecks_domains/ directory). With --static, builds and serves a static app.
#
#   hecks domain serve [--domain NAME] [--port 9292] [--rpc] [--static]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      include Hecks::NamingHelpers
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
        if multi_domain_dir?
          serve_multi(options[:port])
        else
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
      end

      private

      def multi_domain_dir?
        dir = options[:domain] || Dir.pwd
        domains_dir = File.join(dir, "hecks_domains")
        domains_dir = File.join(dir, "domains") unless File.directory?(domains_dir)
        File.directory?(domains_dir)
      end

      def serve_multi(port)
        dir = options[:domain] || Dir.pwd
        require "hecks_serve"
        result = Hecks.boot(dir)
        if result.is_a?(Array)
          domains = result.map(&:domain)
          HTTP::MultiDomainServer.new(domains, result, port: port).run
        else
          HTTP::DomainServer.new(result.domain, port: port).run
        end
      end

      def serve_static(domain, port)
        require "tmpdir"
        dir = Dir.mktmpdir("hecks-serve-")
        output = Hecks.build_static(domain, output_dir: dir)
        lib_path = File.join(output, "lib")
        $LOAD_PATH.unshift(lib_path)
        gem_name = domain.gem_name
        require gem_name
        mod = Object.const_get(domain_module_name(domain.name))
        say "Serving #{mod.name} (static) on http://localhost:#{port}", :green
        mod.serve(port: port)
      ensure
        FileUtils.rm_rf(dir) if dir && Dir.exist?(dir)
      end
    end
  end
end
