require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_modules"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Module DSL, registries, and discovery for Hecks"
  spec.description   = "Provides lazy_registry DSL, self-registration infrastructure, and module discovery for Hecks sub-gems"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"
end
