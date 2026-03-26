require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_watchers"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.summary       = "File watchers for Hecks development — size, isolation, autoloads, specs"
  spec.description   = "File watchers for Hecks development — size, isolation, autoloads, specs"

  spec.required_ruby_version = ">= 3.0"
  spec.require_paths = ["lib"]
  spec.files         = Dir["lib/**/*"]
end
