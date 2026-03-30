Hecks::CLI.register_command(:web_console, "Start the browser-based workshop",
  args: ["NAME"],
  options: {
    port: { type: :numeric, default: 4567, desc: "Server port" },
    domain: { type: :string, desc: "Path to hecks_domain.rb file" }
  }
) do |name = nil|
  port = options.fetch(:port, 4567)
  domain = options[:domain]
  Hecks::Workshop::WebRunner.new(name: name, port: port, domain: domain).run
end
