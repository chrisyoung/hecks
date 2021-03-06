# frozen_string_literal: true
require 'sinatra'
require 'hecks-application'
require 'json'
require_relative 'methods'
require_relative 'cli/cli'

module HecksAdapters
  # Wrap your domain in a cozy Resource Server.  This file maps the routes to
  # methods on your domain models
  class ResourceServer < Sinatra::Base
    configure do
      set :raise_errors, true
      set :show_exceptions, false
    end

    def initialize(app: nil, application_adapter:)
      super(app)
      @methods = Methods.new(application_adapter: application_adapter)
    end

    get '/:module_name/:id' do |module_name, id|
      command = methods.read.call(id: id, module_name: module_name)
      body command.result
      status command.status
    end

    post '/:module_name' do |module_name|
      command = methods.create.call(body: request.body, module_name: module_name)
      status command.status
      body   command.result
    end

    put '/:module_name/:id' do |module_name, id|
      command = methods.update.call(
        id:          id,
        body:        request.body,
        module_name: module_name
      )
      status command.status
      body   command.result
    end

    delete '/:module_name/:id' do |module_name, id|
      command = methods.delete.call(id: id, module_name: module_name)
      status command.status
      body   command.result
    end

    private

    attr_reader :methods
  end
end
