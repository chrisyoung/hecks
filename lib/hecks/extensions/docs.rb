# Hecks::ExtensionDocs
#
# Metadata registry for extensions. Each entry describes what an
# extension does, how to install it, and a usage example. Used by
# ReadmeGenerator for the main README and for per-extension READMEs.
#
#   Hecks::ExtensionDocs.all
#   Hecks::ExtensionDocs.generate_readmes(root)
#
module Hecks
  module ExtensionDocs
    EXTENSIONS = [
      {
        gem: "hecks_sqlite",
        name: "SQLite",
        category: :persistence,
        description: "SQLite persistence — zero-config, file-based SQL database",
        gemfile: 'gem "hecks_sqlite"',
        example: "# Just add the gem. SQLite auto-wires on boot.\nCat.create(name: \"Whiskers\")\nCat.all  # persisted to SQLite"
      },
      {
        gem: "hecks_postgres",
        name: "PostgreSQL",
        category: :persistence,
        description: "PostgreSQL persistence — production-grade relational database",
        gemfile: 'gem "hecks_postgres"',
        example: "# Set HECKS_DB_HOST, HECKS_DB_NAME, HECKS_DB_USER\nCatsDomain.boot(adapter: { type: :postgres, host: \"localhost\", database: \"cats\" })"
      },
      {
        gem: "hecks_mysql",
        name: "MySQL",
        category: :persistence,
        description: "MySQL persistence — widely deployed relational database",
        gemfile: 'gem "hecks_mysql"',
        example: "# Set HECKS_DB_HOST, HECKS_DB_NAME, HECKS_DB_USER env vars"
      },
      {
        gem: "hecks_live",
        name: "Live Events",
        category: :realtime,
        description: "Real-time domain event streaming via Turbo Streams + ActionCable",
        gemfile: 'gem "hecks_live"',
        example: "# Rails view:\n<%= turbo_stream_from \"hecks_live_events\" %>\n<div id=\"event-feed\"></div>\n# Events auto-prepend. No custom JS."
      },
      {
        gem: "hecks_on_rails",
        name: "Rails (Full)",
        category: :rails,
        description: "Bundles ActiveHecks + HecksLive — one gem for Rails apps",
        gemfile: 'gem "hecks_on_rails"',
        example: "rails generate active_hecks:init\n# That's it. Everything wires up."
      },
      {
        gem: "hecks_serve",
        name: "HTTP Server",
        category: :server,
        description: "REST and JSON-RPC server with OpenAPI and JSON Schema generation",
        gemfile: 'gem "hecks_serve"',
        example: "CatsDomain.serve(port: 9292)"
      },
      {
        gem: "hecks_ai",
        name: "MCP Server",
        category: :server,
        description: "Model Context Protocol — expose your domain to AI agents",
        gemfile: 'gem "hecks_ai"',
        example: "CatsDomain.mcp"
      },
      {
        gem: "hecks_auth",
        name: "Auth",
        category: :middleware,
        description: "Actor-based access control on commands",
        gemfile: 'gem "hecks_auth"',
        example: "# DSL: actor \"Admin\" on commands\nHecks.actor = current_user\n# Middleware checks role automatically"
      },
      {
        gem: "hecks_audit",
        name: "Audit Trail",
        category: :middleware,
        description: "Immutable event log with command context, actor, and tenant",
        gemfile: 'gem "hecks_audit"',
        example: "# Auto-records every domain event.\n# Pairs with hecks_auth for actor tracking."
      },
      {
        gem: "hecks_pii",
        name: "PII Protection",
        category: :middleware,
        description: "Mark attributes as PII — masking, redaction, and GDPR erasure",
        gemfile: 'gem "hecks_pii"',
        example: "# DSL: attribute :email, String, pii: true\nCatsDomain.erase_pii(customer_id)"
      },
      {
        gem: "hecks_tenancy",
        name: "Multi-tenancy",
        category: :middleware,
        description: "Tenant isolation — same domain, different data per tenant",
        gemfile: 'gem "hecks_tenancy"',
        example: "# DSL: tenancy :column\nHecks.tenant = \"acme\"\nCat.all  # only acme's cats"
      },
      {
        gem: "hecks_idempotency",
        name: "Idempotency",
        category: :middleware,
        description: "Command deduplication by fingerprinting within a TTL window",
        gemfile: 'gem "hecks_idempotency"',
        example: "# Same command re-executed within TTL returns cached result.\n# HECKS_IDEMPOTENCY_TTL=300"
      },
      {
        gem: "hecks_rate_limit",
        name: "Rate Limiting",
        category: :middleware,
        description: "Sliding window rate limiting per actor",
        gemfile: 'gem "hecks_rate_limit"',
        example: "# HECKS_RATE_LIMIT=60  (max commands per window)\n# HECKS_RATE_PERIOD=60 (window in seconds)"
      },
      {
        gem: "hecks_retry",
        name: "Retry",
        category: :middleware,
        description: "Auto-retry failed commands with exponential backoff",
        gemfile: 'gem "hecks_retry"',
        example: "# Only retries transient errors, not domain errors.\n# HECKS_RETRY_MAX=3\n# HECKS_RETRY_DELAY=0.1"
      },
      {
        gem: "hecks_transactions",
        name: "Transactions",
        category: :middleware,
        description: "Wraps command execution in database transactions when SQL is present",
        gemfile: 'gem "hecks_transactions"',
        example: "# Auto-detects Sequel repositories.\n# Falls through for memory adapters."
      },
      {
        gem: "hecks_logging",
        name: "Logging",
        category: :middleware,
        description: "Structured command logging — name, duration, actor, tenant",
        gemfile: 'gem "hecks_logging"',
        example: "# Output:\n# [hecks] CreatePizza 0.3ms actor=admin tenant=acme"
      },
      {
        gem: "hecks_cqrs",
        name: "CQRS",
        category: :persistence,
        description: "Named persistence connections for read/write separation",
        gemfile: 'gem "hecks_cqrs"',
        example: "CatsDomain.boot do\n  persist_to :write, :sqlite\n  persist_to :read, :sqlite, database: \"read.db\"\nend"
      },
    ].freeze

    def self.all
      EXTENSIONS
    end

    def self.by_category
      EXTENSIONS.group_by { |e| e[:category] }
    end

    # Generate a README for each extension from its source file header.
    def self.generate_readmes(root)
      docs_dir = File.join(root, "docs", "extensions")
      Dir.mkdir(docs_dir) unless File.directory?(docs_dir)
      generated = []

      EXTENSIONS.each do |ext|
        source = File.join(root, "lib", "#{ext[:gem]}.rb")
        next unless File.exist?(source)

        header = extract_header(source)
        readme = build_readme(ext, header)
        path = File.join(docs_dir, "#{ext[:gem]}.md")
        File.write(path, readme)
        generated << path
      end

      generated
    end

    def self.extract_header(path)
      lines = File.readlines(path)
      comment_lines = []
      lines.each do |line|
        break unless line.start_with?("#") || line.strip.empty?
        comment_lines << line.sub(/^#\s?/, "").rstrip if line.start_with?("#")
      end
      # Drop the class name line
      comment_lines.shift if comment_lines.first&.match?(/\A\w+\z/)
      comment_lines.join("\n").strip
    end

    def self.build_readme(ext, header)
      lines = []
      lines << "# #{ext[:name]}"
      lines << ""
      lines << ext[:description]
      lines << ""
      lines << "## Install"
      lines << ""
      lines << "```ruby"
      lines << "# Gemfile"
      lines << ext[:gemfile]
      lines << "```"
      lines << ""
      lines << "Add the gem and it auto-wires on boot. No configuration needed."
      lines << ""
      lines << "## Usage"
      lines << ""
      lines << "```ruby"
      lines << ext[:example]
      lines << "```"
      lines << ""
      if header.length > 10
        lines << "## Details"
        lines << ""
        lines << header
        lines << ""
      end
      lines.join("\n")
    end

    private_class_method :extract_header, :build_readme
  end
end
