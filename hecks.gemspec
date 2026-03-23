lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Hexagonal DDD framework for Ruby"
  spec.description   = "Define domains with a Ruby DSL, generate pure versioned domain gems"
  spec.homepage      = "https://github.com/christopheryoung/hecks"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "bin/*"]
  spec.bindir        = "bin"
  spec.executables   = ["hecks"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "sequel", "~> 5.0"
  spec.add_dependency "rwordnet", ">= 1.0", "< 3.0"
  spec.add_dependency "mcp", ">= 0.1", "< 2.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "activemodel", ">= 6.0", "< 10.0"
  spec.add_development_dependency "sqlite3", ">= 1.4", "< 3.0"
end
