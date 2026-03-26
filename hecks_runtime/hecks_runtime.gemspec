require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_runtime"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Runtime wiring, ports, mixins, and middleware for Hecks"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"
  spec.add_dependency "hecksties", Hecks::VERSION
  spec.add_dependency "hecks_model", Hecks::VERSION
end
