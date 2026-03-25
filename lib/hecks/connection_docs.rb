# Hecks::ConnectionDocs
#
# Metadata registry for connection gems. Each entry describes a gem that
# extends Hecks with an external integration (database, server, AI, etc.).
# Used by ReadmeGenerator to produce the {{connections}} section.
#
#   Hecks::ConnectionDocs.all
#   # => [{ gem: "hecks_sqlite", name: "SQLite", ... }, ...]
#
module Hecks
  module ConnectionDocs
    CONNECTIONS = [
      {
        gem: "hecks_sqlite",
        name: "SQLite",
        description: "SQLite persistence — zero-config, file-based SQL database",
        gemfile: 'gem "hecks_sqlite"',
        example: "# Just add the gem. SQLite auto-wires on boot.\nCat.create(name: \"Whiskers\")\nCat.all  # persisted to SQLite"
      },
      {
        gem: "hecks_postgres",
        name: "PostgreSQL",
        description: "PostgreSQL persistence — production-grade relational database",
        gemfile: 'gem "hecks_postgres"',
        example: "# Set HECKS_DB_HOST, HECKS_DB_NAME, HECKS_DB_USER env vars\n# or configure in boot block:\nCatsDomain.boot(adapter: { type: :postgres, host: \"localhost\", database: \"cats\" })"
      },
      {
        gem: "hecks_mysql",
        name: "MySQL",
        description: "MySQL persistence — widely deployed relational database",
        gemfile: 'gem "hecks_mysql"',
        example: "# Set HECKS_DB_HOST, HECKS_DB_NAME, HECKS_DB_USER env vars"
      },
      {
        gem: "hecks_serve",
        name: "HTTP Server",
        description: "REST and JSON-RPC server — serve your domain over HTTP",
        gemfile: 'gem "hecks_serve"',
        example: "CatsDomain.serve(port: 9292)"
      },
      {
        gem: "hecks_ai",
        name: "MCP Server",
        description: "Model Context Protocol — expose your domain to AI agents",
        gemfile: 'gem "hecks_ai"',
        example: "CatsDomain.mcp"
      },
    ].freeze

    def self.all
      CONNECTIONS
    end
  end
end
