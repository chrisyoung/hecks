# MCP Server

Model Context Protocol — expose your domain to AI agents

## Install

```ruby
# Gemfile
gem "hecks_ai"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
CatsDomain.mcp
```

## Details

MCP (Model Context Protocol) server connection for Hecks domains.
Exposes domain commands, queries, and session tools to AI agents.

Future gem: hecks_ai

  require "hecks_ai"
  Hecks::McpServer.new.run
