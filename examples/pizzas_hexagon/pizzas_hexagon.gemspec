Gem::Specification.new do |s|
  s.name        = 'pizzas_hexagon'
  s.homepage    = "https://github.com/chrisyoung/heckson"
  s.version     = '0.0.1'
  s.date        = '2016-08-27'
  s.summary     = "Pizza Hexagon"
  s.description = "A domain library"
  s.authors     = ["Chris Young"]
  s.email       = 'chris@example.com'
  s.files       = Dir["lib/**/*"]
  s.license     = 'MIT'

  s.add_development_dependency 'rspec', "~> 3.5"
  s.add_development_dependency 'guard-rspec', "~> 4.7"
  s.add_development_dependency 'simplecov', "~> 0.12"
  s.add_development_dependency 'pry', "~> 0.10"

  # s.add_runtime_dependency 'dry-validation'
  # s.add_runtime_dependency 'mysql2'
  s.add_runtime_dependency 'activerecord', "~> 5.0"
  s.add_runtime_dependency 'pizzas_domain', "~> 0.0"
  s.add_runtime_dependency 'sinatra', "~> 1.4"
  s.add_runtime_dependency 'json', "~> 2.0"
end