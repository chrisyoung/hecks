require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_multidomain"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Multi-domain support for Hecks"
  spec.description   = "Filtered event bus, cross-domain validation, event directionality, promote, and cross-domain queries/views"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "hecksties",     Hecks::VERSION
  spec.add_dependency "hecks_runtime", Hecks::VERSION
end
