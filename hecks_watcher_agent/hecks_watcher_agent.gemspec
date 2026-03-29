require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_watcher_agent"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Autonomous agent that fixes watcher issues via PRs"
  spec.description   = "Reads watcher logs, applies fixes (Ruby for simple, Claude Code for complex), and opens pull requests"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "hecks", Hecks::VERSION
end
