# HecksSqlite
#
# SQLite persistence connection for Hecks domains. Auto-wires when present
# in the Gemfile — no configuration needed. Uses Sequel with sqlite3.
#
# Future gem: hecks_sqlite
#
#   # Gemfile
#   gem "cats_domain"
#   gem "hecks_sqlite"   # that's it — SQLite auto-wires
#
require_relative "hecks_persist"

Hecks.register_connection(:sqlite) do |domain_mod, domain, runtime|
  require "sequel"
  require "sqlite3"
  db = Sequel.sqlite
  adapters = Hecks::Boot::SqlBoot.setup(domain, db)
  adapters.each { |name, repo| runtime.swap_adapter(name, repo) }
end
