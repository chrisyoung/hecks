Hecks::CLI.register_command(:serve, "Serve a domain as HTTP (default) or JSON-RPC (--rpc)", group: "Core",
  options: {
    domain:    { type: :string,  desc: "Domain gem name or path" },
    version:   { type: :string,  desc: "Domain version" },
    port:      { type: :numeric, default: 9292, desc: "HTTP port" },
    rpc:       { type: :boolean, default: false, desc: "JSON-RPC" },
    live:      { type: :boolean, default: false, desc: "WebSocket server" },
    live_port: { type: :numeric, default: 9293, desc: "WebSocket port" },
    static:    { type: :boolean, default: false, desc: "Serve with static UI" }
  }
) do

  multi_domain_dir = lambda do
    dir = options[:domain] || Dir.pwd
    domains_dir = File.join(dir, "hecks_domains")
    domains_dir = File.join(dir, "domains") unless File.directory?(domains_dir)
    File.directory?(domains_dir)
  end

  serve_multi = lambda do |port|
    dir = options[:domain] || Dir.pwd
    require "hecks_serve"
    result = Hecks.boot(dir)
    if result.is_a?(Array)
      domains = result.map(&:domain)
      Hecks::HTTP::MultiDomainServer.new(domains, result, port: port).run
    else
      Hecks::HTTP::DomainServer.new(result.domain, port: port).run
    end
  end

  serve_static = lambda do |domain, port|
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

  if multi_domain_dir.call
    serve_multi.call(options[:port])
  else
    domain = resolve_domain_option
    next unless domain
    if options[:static]
      serve_static.call(domain, options[:port])
    elsif options[:rpc]
      require "hecks_serve"
      Hecks::HTTP::RpcServer.new(domain, port: options[:port]).run
    else
      require "hecks_serve"
      server = Hecks::HTTP::DomainServer.new(domain, port: options[:port],
        live: options[:live], live_port: options[:live_port])
      server.run
    end
  end
end
