require "hecks"
require "pizzas_domain"

Hecks.configure do
  domain "pizzas_domain"
  adapter :memory
end
