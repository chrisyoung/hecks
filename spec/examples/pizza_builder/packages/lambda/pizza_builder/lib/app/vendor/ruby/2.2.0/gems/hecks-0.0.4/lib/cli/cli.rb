# frozen_string_literal: true
require 'active_support/inflector'
require 'pry'
require_relative 'command_runner'
require_relative 'commands'

module Hecks
  class CLI < Thor
    package_name 'hecks'

    desc 'generate', 'generate'
    subcommand('generate', Generate)

    desc 'package', 'package'
    subcommand('package', Package) if File.file?('HECKS')

    long_desc      'Generate a domain'
    method_option  :dryrun,
                   aliases:  '-d',
                   type:     :boolean,
                   desc:     'Output commands without running'

    register(New, 'new', 'new', 'Create a new Domain') if File.file?('HECKS')
  end
end