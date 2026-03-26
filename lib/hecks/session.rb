require "fileutils"
require_relative "session/build_actions"
require_relative "session/play_mode"
require_relative "session/presenter"
require_relative "session/handles/aggregate_handle"
require_relative "session/system_browser"
require_relative "session/console_runner"
require_relative "session/playground"

# Hecks::Session
#
# Interactive domain-building session for REPL-driven development. Supports
# two modes: "sketch" (define aggregates, commands, policies) and "play"
# (execute commands and inspect events against a live compiled domain).
#
# A Session holds a collection of AggregateBuilder instances keyed by name,
# each wrapped in an AggregateHandle for interactive use. The session can
# validate the domain, compile it into a gem, switch into play mode for
# live execution, and serialize back to DSL source.
#
# Includes:
# - BuildActions  -- validate, preview, build, save, to_dsl
# - PlayMode      -- play!, sketch!, events, history, reset!
# - Presenter     -- describe, status, inspect
# - SystemBrowser -- browse (tree view of domain elements)
#
#   session = Hecks.session("Pizzas")
#   session.aggregate("Pizza") { attribute :name, String }
#   session.validate
#   session.build
#   session.play!
#

module Hecks
  class Session
    include BuildActions
    include PlayMode
    include Presenter
    include SystemBrowser

    attr_reader :name, :playground, :aggregate_builders

    # Initialize a new session for the given domain name.
    #
    # Sets up empty aggregate builders, handles, custom verbs, and defaults
    # to sketch mode with no playground.
    #
    # @param name [String] the domain name (e.g. "Pizzas", "Accounting")
    def initialize(name)
      @name = name
      @aggregate_builders = {}
      @handles = {}
      @custom_verbs = []
      @active_hecks = false
      @mode = :sketch
      @playground = nil
    end

    # Return the current session mode.
    #
    # @return [Symbol] either +:sketch+ or +:play+
    def mode
      @mode
    end

    # Check whether the session is in sketch (build) mode.
    #
    # @return [Boolean] true when the session is in sketch mode
    def sketch?
      @mode == :sketch
    end

    # Check whether the session is in play (runtime) mode.
    #
    # @return [Boolean] true when the session is in play mode
    def play?
      @mode == :play
    end

    # Get or create an aggregate by name, returning an interactive handle.
    #
    # If a block is given, it is evaluated in the context of the underlying
    # AggregateBuilder (so +attribute+, +command+, +policy+, etc. are available).
    # The method always returns an AggregateHandle that can be used for
    # incremental building (e.g. +pizza.attr :name, String+).
    #
    # @param name [String] the aggregate name (will be sanitized to a valid constant)
    # @yield optional block evaluated on the AggregateBuilder for batch definition
    # @return [AggregateHandle] interactive handle for the aggregate
    def aggregate(name, &block)
      name = normalize_name(name)
      builder = @aggregate_builders[name] ||= DSL::AggregateBuilder.new(name)
      builder.instance_eval(&block) if block

      handle = @handles[name] ||= AggregateHandle.new(name, builder, domain_module: @name.gsub(/\s+/, "") + "Domain", session: self)

      if block
        agg = builder.build
        puts "#{name} (#{aggregate_summary(agg)})"
      end

      handle
    end

    # Build and return a Domain structure from the current aggregate definitions.
    #
    # Constructs a DomainModel::Structure::Domain by building each aggregate
    # from its builder, collecting them along with any custom verbs.
    #
    # @return [DomainModel::Structure::Domain] the fully assembled domain object
    def to_domain
      aggregates = @aggregate_builders.values.map(&:build)
      DomainModel::Structure::Domain.new(name: @name, aggregates: aggregates, custom_verbs: @custom_verbs)
    end

    # Compile the domain and activate ActiveHecks (Rails persistence layer).
    #
    # Loads the domain into memory, then attempts to require the active_hecks gem
    # and activate it. Prints a warning if the gem is not installed.
    #
    # @return [Module] the loaded domain module, or nil if active_hecks is unavailable
    def active_hecks!
      @active_hecks = true
      domain = to_domain
      mod = Hecks.load_domain(domain, force: true, skip_validation: true)
      begin
        require "active_hecks"
      rescue LoadError
        puts "active_hecks gem not installed. Add it to your Gemfile."
        return mod
      end
      ActiveHecks.activate(mod, domain: domain)
      puts "ActiveHecks loaded for #{domain.module_name}Domain"
      mod
    end

    # Check if ActiveHecks has been activated for this session.
    #
    # @return [Boolean] true if +active_hecks!+ has been called
    def active_hecks?
      @active_hecks
    end

    # Register a custom verb for use in command naming.
    #
    # Custom verbs extend the set of recognized action words that can appear
    # in command names (e.g. "Bake", "Ferment"). Duplicates are ignored.
    #
    # @param word [String, Symbol] the verb to register
    # @return [Session] self, for chaining
    def add_verb(word)
      @custom_verbs << word.to_s unless @custom_verbs.include?(word.to_s)
      self
    end

    # Return the list of aggregate names defined in this session.
    #
    # @return [Array<String>] aggregate names (sanitized constant form)
    def aggregates
      @aggregate_builders.keys
    end

    # Remove an aggregate by name from the session.
    #
    # Deletes both the builder and its handle. Prints confirmation or
    # an error if no aggregate with that name exists.
    #
    # @param aggregate_name [String] the name of the aggregate to remove
    # @return [Session] self, for chaining
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

    # Normalize a user-provided name into a valid Ruby constant string.
    #
    # @param name [String] the raw name
    # @return [String] sanitized constant name
    def normalize_name(name)
      Hecks::Utils.sanitize_constant(name)
    end

    # Build a human-readable summary string for an aggregate.
    #
    # Lists counts of attributes, value objects, entities, commands, and
    # policies. Returns "empty" if the aggregate has none of these.
    #
    # @param agg [DomainModel::Structure::Aggregate] the built aggregate
    # @return [String] summary like "3 attributes, 2 commands"
    def aggregate_summary(agg)
      parts = []
      parts << "#{agg.attributes.size} attributes" unless agg.attributes.empty?
      parts << "#{agg.value_objects.size} value objects" unless agg.value_objects.empty?
      parts << "#{agg.entities.size} entities" unless agg.entities.empty?
      parts << "#{agg.commands.size} commands" unless agg.commands.empty?
      parts << "#{agg.policies.size} policies" unless agg.policies.empty?
      parts.empty? ? "empty" : parts.join(", ")
    end
  end
end
