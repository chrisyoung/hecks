#!/usr/bin/env ruby
# Re-exec outside Bundler if we're inside a parent bundle
if ENV["BUNDLE_GEMFILE"] && !ENV["HECKS_STATIC"]
  clean_env = ENV.to_h.reject { |k, _| k.start_with?("BUNDLE") || k == "RUBYOPT" || k == "RUBYLIB" }
  clean_env["HECKS_STATIC"] = "1"
  exec(clean_env, RbConfig.ruby, $0, *ARGV)
end
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "__GEM__"

command = ARGV.shift

case command
when "serve", "ui"
  port = ARGV.find { |a| a =~ /^\d+$/ }&.to_i || 9292
  adapter = ARGV.find { |a| a =~ /^--adapter=/ }&.then { |a| a.split("=").last&.to_sym } || :memory
  __MOD__.reboot(adapter: adapter) if adapter != :memory
  puts "__MOD__ on http://localhost:#{port} (adapter: #{adapter})"
  __MOD__.serve(port: port)
when "console"
  require "irb"
  puts "__MOD__ console (memory adapter)"
  IRB.start
when "generate"
  ENV["HECKS_SKIP_BOOT"] = "1"
  project_root = File.expand_path("..", __dir__)
  domain_file = File.join(project_root, "hecks_domain.rb")
  unless File.exist?(domain_file)
    puts "No hecks_domain.rb found in #{project_root}"
    exit 1
  end
  require "hecks"
  domain = eval(File.read(domain_file), nil, domain_file, 1)
  require "hecks_static"
  HecksStatic::GemGenerator.new(domain, output_dir: File.dirname(project_root)).generate
  puts "Regenerated domain from hecks_domain.rb"
when "info"
  puts "__MOD__"
  puts "  Adapter: #{__MOD__.config[:adapter]}"
  puts "  Events:  #{__MOD__.events.size}"
  __MOD__.domain_info.each do |name, info|
    puts "  #{name}: #{info[:count]} records, #{info[:commands].size} commands"
    info[:ports].each { |role, methods| puts "    #{role}: #{methods.join(', ')}" }
  end
else
  puts "__CMD__ — __MOD__ static domain"
  puts ""
  puts "Commands:"
  puts "  __CMD__ serve [PORT] [--adapter=memory|filesystem]   Start HTTP server with UI"
  puts "  __CMD__ ui [PORT]                                     Alias for serve"
  puts "  __CMD__ console                                       IRB with domain loaded"
  puts "  __CMD__ generate                                      Regenerate domain from hecks_domain.rb"
  puts "  __CMD__ info                                          Show domain config"
end
