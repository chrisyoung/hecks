# Hecks::Session
#
# Interactive domain-building session for REPL-driven development. Supports
# two modes: "build" (define aggregates, commands, policies) and "play"
# (execute commands and inspect events against a live compiled domain).
#
# Sessions sit between the DSL layer and the Generators/Playground -- they
# accumulate builder state and can compile, validate, preview, save, or
# generate at any point.
#
#   session = Hecks.session("Pizzas")
#   session.aggregate "Pizza" do
#     attribute :name, String
#     command "CreatePizza" do
#       attribute :name, String
#     end
#   end
#   session.validate    # => true
#   session.preview     # prints generated Ruby code
#   session.save        # write domain.rb
#   session.build       # generate domain gem
#   session.play!       # switch to play mode
#   session.execute("CreatePizza", name: "Margherita")
#
require "fileutils"
require_relative "session/play_mode"
require_relative "session/presenter"
require_relative "session/handles/aggregate_handle"
require_relative "session/console_runner"
require_relative "session/playground"

module Hecks
  class Session
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
    # With a block: also evaluates the DSL block
    # Without a block: just returns the handle
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

    # Build the domain model from current state
    def to_domain
      aggregates = @aggregate_builders.values.map(&:build)
      DomainModel::Structure::Domain.new(name: @name, aggregates: aggregates)
    end

    # Validate current domain state
    def validate
      domain = to_domain
      valid, errors = Hecks.validate(domain)

      if valid
        puts "Valid (#{domain.aggregates.size} aggregates, #{total_commands(domain)} commands, #{total_events(domain)} events)"
      else
        puts "Invalid:"
        errors.each { |e| puts "  - #{e}" }
      end

      valid
    end

    # Preview generated code for an aggregate
    def preview(aggregate_name = nil)
      domain = to_domain

      if aggregate_name
        puts Hecks.preview(domain, aggregate_name)
      else
        domain.aggregates.each do |agg|
          puts "# === #{agg.name} ==="
          puts Hecks.preview(domain, agg.name)
          puts
        end
      end
      nil
    end

    # Generate the domain gem
    def build(version: nil, output_dir: ".")
      domain = to_domain

      version ||= next_version
      path = Hecks.build(domain, version: version, output_dir: output_dir)
      puts "Built #{domain.gem_name} v#{version} -> #{path}/"
      path
    end

    # Save the domain definition to domain.rb
    def save(path = "hecks_domain.rb")
      File.write(path, to_dsl)
      puts "Saved to #{path}"
      path
    end

    # List aggregate names
    def aggregates
      @aggregate_builders.keys
    end

    # Remove an aggregate
    def remove(aggregate_name)
      if @aggregate_builders.delete(aggregate_name)
        @handles.delete(aggregate_name)
        puts "Removed #{aggregate_name}"
      else
        puts "No aggregate named #{aggregate_name}"
      end
      self
    end

    # Generate DSL source code from current state
    def to_dsl
      DslSerializer.new(to_domain).serialize
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

    def total_commands(domain)
      domain.aggregates.sum { |a| a.commands.size }
    end

    def total_events(domain)
      domain.aggregates.sum { |a| a.events.size }
    end

    def next_version
      Versioner.new(".").next
    end

  end
end
