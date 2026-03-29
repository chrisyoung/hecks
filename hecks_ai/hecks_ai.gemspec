require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_ai"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "AI integration for Hecks"
  spec.description   = "MCP server, aggregate tools, and AI-driven domain building"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "hecks_workshop", Hecks::VERSION
end
