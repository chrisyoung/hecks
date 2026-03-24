# HecksCli
#
# Thor-based command-line interface for Hecks. Provides domain lifecycle
# commands (init, build, serve, console, mcp, validate, dump, etc.) and
# gem packaging commands.
#
# Future gem: hecks_cli
#
#   require "hecks_cli"
#   Hecks::CLI.start(ARGV)
#
require_relative "hecks_cli/cli"
