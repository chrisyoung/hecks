require_relative "hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Hexagonal DDD framework for Ruby"
  spec.description   = "Meta-gem that installs all Hecks components"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = [
    "README.md", "FEATURES.md", "hecks_logo.png",
    "lib/hecks.rb",
    "bin/hecks", "bin/hecks_claude"
  ]
  spec.require_paths = ["lib"]
  spec.bindir        = "bin"
  spec.executables   = ["hecks"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "bluebook", Hecks::VERSION
  spec.add_dependency "hecks_ai", Hecks::VERSION
  spec.add_dependency "hecks_on_rails", Hecks::VERSION
  spec.add_dependency "hecks_workshop", Hecks::VERSION
  spec.add_dependency "hecksagon", Hecks::VERSION
  spec.add_dependency "hecksties", Hecks::VERSION
end
