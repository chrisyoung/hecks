Hecks::CLI.register_command(:regenerate_examples, "Regenerate all example outputs from the pizzas domain") do
  root = File.expand_path("../..", __dir__)
  pizzas = File.join(root, "examples", "pizzas")

  Dir.chdir(pizzas) do
    say "Loading pizzas domain...", :green
    Dir["*Bluebook"].each { |f| Kernel.load(f) }
    domain = Hecks.last_domain

    say "Building domain gem...", :green
    Hecks.build(domain, output_dir: ".")
    FileUtils.rm_rf(File.join(root, "examples", "pizzas_domain"))
    FileUtils.mv("pizzas_domain", File.join(root, "examples", "pizzas_domain"))

    say "Building static Ruby...", :green
    Hecks.build_static(domain, output_dir: ".", smoke_test: false)

    say "Building Go binary...", :green
    FileUtils.rm_rf("pizzas_static_go")
    Hecks.build_go(domain, output_dir: ".", smoke_test: false)

    say "Building Rails app...", :green
    FileUtils.rm_rf(File.join(root, "examples", "pizzas_rails"))
    require "hecks/generators/rails_generator"
    Hecks::Generators::RailsGenerator.new(domain).generate(output_dir: ".")
    rails_dir = File.join(root, "examples", "pizzas_rails")
    FileUtils.mv("pizzas_rails", rails_dir)
    FileUtils.rm_rf(File.join(rails_dir, ".git"))
  end

  say ""
  say "Regenerated:", :green
  say "  examples/pizzas_domain/"
  say "  examples/pizzas/pizzas_static_ruby/"
  say "  examples/pizzas/pizzas_static_go/"
  say "  examples/pizzas_rails/"
end
