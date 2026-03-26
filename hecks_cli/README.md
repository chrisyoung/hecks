# HecksCLI

The command-line interface — Thor-based CLI for building, serving, and managing domains.

Each command is its own file. Also owns the HTTP/RPC serve extension for exposing domains over the network.

## Commands

`new`, `build`, `console`, `validate`, `serve`, `mcp`, `docs`, `dump`, `gem`, `init`, `list`, `migrations`, `version`, `info`, `context_map`, `generate_config`, `generate_sinatra`, `generate_stub`

## Extensions

- **extensions/serve/** — DomainServer (HTTP), RpcServer (JSON-RPC), RouteBuilder
