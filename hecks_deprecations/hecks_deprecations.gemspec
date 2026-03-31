require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_deprecations"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Deprecated hash-style access for Hecks value objects"
  spec.description   = "Provides deprecated hash-style access with warnings. Modules self-register their deprecations."
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "hecksties", Hecks::VERSION
end
