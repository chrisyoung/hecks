require_relative "../hecksties/lib/hecks/version"

Gem::Specification.new do |spec|
  spec.name          = "hecks_explorer"
  spec.version       = Hecks::VERSION
  spec.authors       = ["Christopher Young"]
  spec.summary       = "Web explorer for Hecks domains"
  spec.description   = "HTML views, renderer, HTTP server, route builder, and RPC server for exploring Hecks domains in the browser"
  spec.homepage      = "https://github.com/chrisyoung/hecks"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "hecks_runtime", Hecks::VERSION
  spec.add_dependency "webrick"
end
