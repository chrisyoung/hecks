# HecksPostgres
#
# PostgreSQL persistence connection for Hecks domains. Auto-wires when
# present in the Gemfile. Uses Sequel with the pg driver.
#
# Future gem: hecks_postgres
#
#   # Gemfile
#   gem "cats_domain"
#   gem "hecks_postgres"   # auto-wires Postgres
#
require_relative "../../hecks_persist"

Hecks.describe_extension(:postgres,
  description: "PostgreSQL persistence via Sequel",
  config: { host: { default: "localhost", desc: "DB host" }, database: { default: nil, desc: "DB name" } },
  wires_to: :repository)

Hecks.register_extension(:postgres) do |domain_mod, domain, runtime|
  require "sequel"
  db = Sequel.connect(adapter: :postgres,
    host:     ENV.fetch("HECKS_DB_HOST", "localhost"),
    database: ENV.fetch("HECKS_DB_NAME", domain.gem_name),
    user:     ENV.fetch("HECKS_DB_USER", nil),
    password: ENV.fetch("HECKS_DB_PASSWORD", nil))
  adapters = Hecks::Boot::SqlBoot.setup(domain, db)
  adapters.each { |name, repo| runtime.swap_adapter(name, repo) }
end
