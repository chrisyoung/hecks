# HTTP Server

REST and JSON-RPC server with OpenAPI and JSON Schema generation

## Install

```ruby
# Gemfile
gem "hecks_serve"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
CatsDomain.serve(port: 9292)
```

## Details

HTTP and JSON-RPC server connection for Hecks domains.
Serves domains over REST and JSON-RPC via WEBrick. Includes
OpenAPI, JSON Schema, and RPC discovery generators.

Future gem: hecks_serve

  require "hecks_serve"
  Hecks::HTTP::DomainServer.new(domain, port: 3000).run
