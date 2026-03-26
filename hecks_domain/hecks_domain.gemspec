require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_domain"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.summary       = "Domain compiler, code generators, and migrations for Hecks"
  spec.description   = "Domain compiler, code generators, and migrations for Hecks"

  spec.required_ruby_version = ">= 3.0"
  spec.require_paths = ["lib"]
  spec.files         = Dir["lib/**/*"]

  spec.add_dependency "hecksties", Hecks::VERSION
  spec.add_dependency "hecks_model", Hecks::VERSION
end
