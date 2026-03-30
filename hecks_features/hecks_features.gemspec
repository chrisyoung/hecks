require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_features"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.summary       = "Vertical slice architecture for Hecks"
  spec.description   = "Extracts vertical slices from domain reactive chains, validates slice boundaries, and generates slice diagrams"

  spec.required_ruby_version = ">= 3.0"
  spec.require_paths = ["lib"]
  spec.files         = Dir["lib/**/*"]

  spec.add_dependency "hecksties", Hecks::VERSION
  spec.add_dependency "bluebook", Hecks::VERSION
end
