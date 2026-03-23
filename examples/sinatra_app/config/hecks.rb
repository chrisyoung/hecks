require "hecks"
require "pizzas_domain"

# Load the domain
domain_file = File.join(Gem.loaded_specs["pizzas_domain"]&.full_gem_path || "../pizzas_domain", "domain.rb")
DOMAIN = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)

# Boot with memory adapters (swap to SQL for production)
APP = Hecks::Services::Application.new(DOMAIN)

# Uncomment for SQL persistence:
# Hecks.configure do
#   domain "pizzas_domain"
#   adapter :sql, database: :sqlite, name: "pizzas.db"
#   include_ad_hoc_queries
# end
