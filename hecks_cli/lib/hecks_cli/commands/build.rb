Hecks::CLI.register_command(:build, "Generate the domain gem", group: "Core",
  options: {
    domain:  { type: :string,  desc: "Domain gem name or path" },
    version: { type: :string,  desc: "Domain version" },
    target:  { type: :string,  desc: "Build target: ruby (default), static, go, rails" },
    static:  { type: :boolean, desc: "Generate static gem (alias for --target static)" }
  }
) do

  domain = resolve_domain_option
  unless domain
    say "Error: must be run from a directory containing hecks_domain.rb", :red
    raise SystemExit.new(1)
  end
  validator = Hecks::Validator.new(domain)
  unless validator.valid?
    say "Domain validation failed:", :red
    validator.errors.each { |e| say "  - #{e}", :red }
    next
  end

  target = options[:target] || (options[:static] ? "static" : "ruby")
  versioner = Hecks::Versioner.new(".")
  version = versioner.next

  build_go_target = lambda do |d|
    output = Hecks.build_go(d, smoke_test: false)
    say "Built #{d.name} Go project", :green
    say "  Output: #{output}/"

    if system("which go > /dev/null 2>&1")
      say "  Compiling Go binary..."
      slug = domain_slug(d.name)
      binary = "#{slug}_server"
      if system("cd #{output} && go mod tidy 2>&1 && go build -o #{binary} ./cmd/#{slug}/ 2>&1")
        say "  Binary: #{output}/#{binary}", :green
      else
        say "  Go compilation failed — run `go build` manually", :yellow
      end
    else
      say "  Go not installed — run `go build` in #{output}/ to compile", :yellow
    end
  end

  case target
  when "go"
    build_go_target.call(domain)
  when "static"
    output = Hecks.build_static(domain, version: version)
    say "Built #{domain.gem_name} v#{version} (static)", :green
    say "  Output: #{output}/"
  when "rails"
    output = Hecks.build_rails(domain, output_dir: ".")
    say "Built Rails app: #{output}/", :green
    say "  cd #{output} && bundle install && rails server"
  else
    output = Hecks.build(domain, version: version)
    say "Built #{domain.gem_name} v#{version}", :green
    say "  Docs: #{output}/docs/"
    say "  Output: #{output}/"
  end
end
