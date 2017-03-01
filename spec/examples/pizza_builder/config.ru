require_relative "lib/pizza_builder.rb"
require 'hecks'

run Hecks::Adapters::ResourceServer.new(
  application_adapter: Hecks::Application.new(
    domain: PizzaBuilder
  )
)
