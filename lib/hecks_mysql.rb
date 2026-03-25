# HecksMysql
#
# MySQL persistence connection for Hecks domains. Auto-wires when
# present in the Gemfile. Uses Sequel with the mysql2 driver.
#
# Future gem: hecks_mysql
#
#   # Gemfile
#   gem "cats_domain"
#   gem "hecks_mysql"   # auto-wires MySQL
#
require_relative "hecks_persist"

Hecks.register_extension(:mysql) do |domain_mod, domain, runtime|
  require "sequel"
  db = Sequel.connect(adapter: :mysql2,
    host:     ENV.fetch("HECKS_DB_HOST", "localhost"),
    database: ENV.fetch("HECKS_DB_NAME", domain.gem_name),
    user:     ENV.fetch("HECKS_DB_USER", "root"),
    password: ENV.fetch("HECKS_DB_PASSWORD", nil))
  adapters = Hecks::Boot::SqlBoot.setup(domain, db)
  adapters.each { |name, repo| runtime.swap_adapter(name, repo) }
end
