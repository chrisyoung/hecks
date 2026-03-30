require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "heksagons"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.summary       = "Hexagonal architecture for Hecks — ports, adapters, and structural glue"
  spec.description   = "The port system that makes any modeling grammar pluggable. Driving ports (inbound), driven ports (outbound), adapter contracts."

  spec.required_ruby_version = ">= 3.0"
  spec.require_paths = ["lib"]
  spec.files         = Dir["lib/**/*"]
end
