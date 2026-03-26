require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_cli"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.summary       = "Command-line interface and HTTP server for Hecks"
  spec.description   = "Command-line interface and HTTP server for Hecks"

  spec.required_ruby_version = ">= 3.0"
  spec.require_paths = ["lib"]
  spec.files         = Dir["lib/**/*"]

  spec.add_dependency "hecksties", Hecks::VERSION
  spec.add_dependency "hecks_runtime", Hecks::VERSION
  spec.add_dependency "thor", "~> 1.0"
end
