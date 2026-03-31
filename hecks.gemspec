require_relative "hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Hexagonal DDD framework for Ruby"
  spec.description   = "Meta-gem that installs all Hecks components: core, model, domain, runtime, session, CLI, and persistence"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = [
    "README.md", "FEATURES.md", "hecks_logo.png",
    "lib/hecks.rb",
    "bin/hecks", "bin/hecks_claude",
    "bin/watch-all", "bin/watch-autoloads", "bin/watch-cli",
    "bin/watch-cross-require", "bin/watch-file-size", "bin/watch-spec-coverage"
  ]
  spec.require_paths = ["lib"]
  spec.bindir        = "bin"
  spec.executables   = ["hecks"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_development_dependency "bluebook", Hecks::VERSION
  spec.add_development_dependency "hecks_ai", Hecks::VERSION
  spec.add_development_dependency "hecks_cli", Hecks::VERSION
  spec.add_development_dependency "hecks_deprecations", Hecks::VERSION
  spec.add_development_dependency "hecks_explorer", Hecks::VERSION
  spec.add_development_dependency "hecks_features", Hecks::VERSION
  spec.add_development_dependency "hecks_multidomain", Hecks::VERSION
  spec.add_development_dependency "hecks_on_rails", Hecks::VERSION
  spec.add_development_dependency "hecks_on_the_go", Hecks::VERSION
  spec.add_development_dependency "hecks_persist", Hecks::VERSION
  spec.add_development_dependency "hecks_runtime", Hecks::VERSION
  spec.add_development_dependency "hecks_smoke", Hecks::VERSION
  spec.add_development_dependency "hecks_static", Hecks::VERSION
  spec.add_development_dependency "hecks_stats", Hecks::VERSION
  spec.add_development_dependency "hecks_templating", Hecks::VERSION
  spec.add_development_dependency "hecks_watcher_agent", Hecks::VERSION
  spec.add_development_dependency "hecks_watchers", Hecks::VERSION
  spec.add_development_dependency "hecks_workshop", Hecks::VERSION
  spec.add_development_dependency "hecksties", Hecks::VERSION
  spec.add_development_dependency "heksagons", Hecks::VERSION
end
