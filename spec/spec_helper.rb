
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    add_filter "/spec/"
  end
end

require "hecksagain"

module InMemoryDomain
  ROOT             = File.expand_path("..", __dir__)
  PIZZAS_BLUEBOOK  = File.join(ROOT, "examples/pizzas/bluebook/pizzas.bluebook")
  PERSISTENCE_PORT = File.join(ROOT, "lib/hecksagain/ports/persistence.port")
  EXTRACTION_PORT  = File.join(ROOT, "lib/hecksagain/ports/extraction.port")
  MEMORY_ADAPTER   = File.join(ROOT, "lib/hecksagain/adapters/driven/memory.adapter")
  PRISM_ADAPTER    = File.join(ROOT, "lib/hecksagain/adapters/driven/prism.adapter")
  POSTGRES_ADAPTER = File.join(ROOT, "lib/hecksagain/adapters/driven/postgres.adapter")

  def boot_in_memory
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(PERSISTENCE_PORT)
      Kernel.load(EXTRACTION_PORT)
      Kernel.load(MEMORY_ADAPTER)
      Kernel.load(PRISM_ADAPTER)
      Kernel.load(PIZZAS_BLUEBOOK)

      # `::` on purpose — a real .hecksagon file is loaded at TOP LEVEL, where an
      # unresolved constant reaches Object's const_missing (ConstShim ->
      # BindingProxy). This block lives inside a module, so a bare `Pizzas`
      # would be looked up here first and reach no hook at all.
      Hecks.hecksagon("Pizzas") { ::Pizzas::Order.persisted_by("Memory") }
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  end
end

RSpec.configure do |config|
  config.include InMemoryDomain

  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random

  # `io: true` marks a spec (or single example) that does real,
  # uncontrolled I/O — a subprocess spawn, a live Postgres/D1
  # connection, a `cargo build` — the kind of thing that made a plain
  # local `bundle exec rspec` slow even though most of it self-skips
  # when the resource isn't reachable. CI (.github/workflows/ci.yml)
  # provisions everything for real and always sets `CI`, so it runs
  # these unfiltered; run them locally on demand with
  # `CI=true bundle exec rspec` or `bundle exec rspec --tag io`.
  config.filter_run_excluding io: true unless ENV["CI"]

  # `qa: true` marks tests that demonstrate known bugs. These are owned
  # by the QA engineer and demonstrate issues that haven't been fixed yet.
  # They are excluded from normal test runs and CI.
  #
  # To run QA bug tests:
  #   rspec --tag qa
  #   rspec spec/qa_bugs_spec.rb
  #
  # As bugs are fixed, tests are moved to the appropriate spec file
  # and the qa: true tag is removed.
  config.filter_run_excluding qa: true
end
