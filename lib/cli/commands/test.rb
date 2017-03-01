class Test < Thor
  include Thor::Actions

  desc 'ci', 'Run and test the generators'
  def ci
    examples
    packages
    domain_adapters
  end

  desc 'domain_adapters', "run the domain adapter specs"
  def domain_adapters
    generate_resource_server('pizza_builder')
  end

  desc 'examples', 'Generate and run the example specs'
  def examples
    reset_example('pizza_builder')
    run('rspec -f d')
  end

  desc 'packages', 'Generate and run the package specs'
  def packages
    build_binary_package('pizza_builder')
    build_lambda_package('pizza_builder')
  end

  private

  def reset_example(name)
    run("cd spec/examples/#{name} && rm -rf lib")
    run("cd spec/examples/#{name} && rm -rf spec")
    run("cd spec/examples/#{name} && hecks new")
  end

  def build_binary_package(name)
    run("cd spec/examples/#{name} && hecks package binary")
  end

  def build_lambda_package(name)
    run("cd spec/examples/#{name} && hecks package lambda")
  end

  def generate_resource_server(name)
    run("cd spec/examples/#{name} && rm -rf config.ru")
    run("cd spec/examples/#{name} && hecks generate resource_server")
    run("cd spec/examples/#{name}")
    run('cd spec/examples/pizza_builder/adapters/sql_database&&rspec')
  end
end
