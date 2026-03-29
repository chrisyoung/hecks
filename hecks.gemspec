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

end
