# Hecks::Session
#
# Interactive domain-building session for REPL-driven development. Supports
# two modes: "build" (define aggregates, commands, policies) and "play"
# (execute commands and inspect events against a live compiled domain).
#
#   session = Hecks.session("Pizzas")
#   session.aggregate("Pizza") { attribute :name, String }
#   session.validate
#   session.build
#   session.play!
#
require "fileutils"
require_relative "session/build_actions"
require_relative "session/play_mode"
require_relative "session/presenter"
require_relative "session/handles/aggregate_handle"
require_relative "session/console_runner"
require_relative "session/playground"

module Hecks
  class Session
    include BuildActions
    include PlayMode
    include Presenter

    attr_reader :name, :playground, :aggregate_builders

    def initialize(name)
      @name = name
      @aggregate_builders = {}
      @handles = {}
      @mode = :build
      @playground = nil
    end

    def mode
      @mode
    end

    def build?
      @mode == :build
    end

    def play?
      @mode == :play
    end

    # Get or create an aggregate, returns a handle for incremental building
    def aggregate(name, &block)
      builder = @aggregate_builders[name] ||= DSL::AggregateBuilder.new(name)
      builder.instance_eval(&block) if block

      handle = @handles[name] ||= AggregateHandle.new(name, builder, domain_module: @name.gsub(/\s+/, "") + "Domain", session: self)

      if block
        agg = builder.build
        puts "#{name} (#{aggregate_summary(agg)})"
      end

      handle
    end

    def to_domain
      aggregates = @aggregate_builders.values.map(&:build)
      DomainModel::Structure::Domain.new(name: @name, aggregates: aggregates)
    end

    def aggregates
      @aggregate_builders.keys
    end

    def remove(aggregate_name)
      if @aggregate_builders.delete(aggregate_name)
        @handles.delete(aggregate_name)
        puts "Removed #{aggregate_name}"
      else
        puts "No aggregate named #{aggregate_name}"
      end
      self
    end

    private

    def aggregate_summary(agg)
      parts = []
      parts << "#{agg.attributes.size} attributes" unless agg.attributes.empty?
      parts << "#{agg.value_objects.size} value objects" unless agg.value_objects.empty?
      parts << "#{agg.commands.size} commands" unless agg.commands.empty?
      parts << "#{agg.policies.size} policies" unless agg.policies.empty?
      parts.empty? ? "empty" : parts.join(", ")
    end
  end
end
