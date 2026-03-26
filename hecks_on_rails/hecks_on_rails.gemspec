require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_on_rails"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Full Rails integration for Hecks domains"
  spec.description   = "Bundles ActiveHecks + HecksLive — one gem for validations, persistence, and real-time"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"
  spec.add_dependency "hecks"
  # These will be added once the gems are published:
  # spec.add_dependency "active_hecks"
  # spec.add_dependency "hecks_live"
end
