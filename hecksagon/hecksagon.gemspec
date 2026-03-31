require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecksagon"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Hexagonal architecture wiring DSL for Hecks"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sequel", ">= 5.0"
end
