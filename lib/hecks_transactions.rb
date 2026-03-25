# HecksTransactions
#
# Command bus middleware that wraps command execution in a database
# transaction when a SQL adapter is present. Checks if the command's
# repository responds to `db` (Sequel repositories do) and wraps in
# `db.transaction { }`. Falls through transparently for memory adapters.
#
# Future gem: hecks_transactions
#
#   require "hecks_transactions"
#   # Automatically registered — all commands through SQL repos
#   # will execute inside a database transaction.
#
require "hecks"

Hecks.register_extension(:transactions) do |domain_mod, domain, runtime|
  runtime.use :transactions do |command, next_handler|
    repo = command.class.respond_to?(:repository) ? command.class.repository : nil
    db = repo.respond_to?(:db) ? repo.db : nil
    if db && db.respond_to?(:transaction)
      db.transaction { next_handler.call }
    else
      next_handler.call
    end
  end
end
