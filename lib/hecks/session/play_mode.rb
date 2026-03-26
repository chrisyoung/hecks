# Hecks::Session::PlayMode
#
# Session mixin for play-mode: executing commands against a live compiled
# domain and inspecting events. Part of the Session layer -- delegates to
# Playground for actual execution.
#
# Play mode compiles the current domain definition into a temporary gem,
# boots a Runtime with in-memory adapters, and lets you execute commands
# and query repositories. All events are captured and can be inspected.
#
# Switching between modes:
# - +play!+ validates the domain, compiles it, and enters play mode
# - +sketch!+ tears down the playground and returns to sketch mode
#
#   session.play!
#   Pizza.create_pizza(name: "Margherita")
#   session.events
#   session.history
#   session.sketch!   # back to sketch mode
#
module Hecks
  class Session
    module PlayMode
      # Switch to play mode by compiling the domain and booting a live runtime.
      #
      # Validates the domain first; if invalid, prints errors and stays in
      # sketch mode. On success, creates a Playground, switches mode to :play,
      # and prints usage hints showing example commands for the first aggregate.
      #
      # @return [Session] self
      def play!
        domain = to_domain
        valid, errors = Hecks.validate(domain)

        unless valid
          puts "Can't enter play mode - domain is invalid:"
          errors.each { |e| puts "  - #{e}" }
          return self
        end

        @playground = Playground.new(domain)
        @mode = :play
        first_agg = domain.aggregates.first
        example_cmd = first_agg&.commands&.first
        if first_agg && example_cmd
          agg_name = first_agg.name
          cmd_snake = Hecks::Utils.underscore(example_cmd.name)
          puts "Entering play mode"
          puts ""
          puts "  #{agg_name}.#{cmd_snake}(...)            # run a command"
          puts "  #{agg_name}.all / #{agg_name}.find(id)   # query"
          puts "  events / history / reset!"
          puts "  sketch!                                 # back to sketch mode"
        else
          puts "Entering play mode"
          puts ""
          puts "  browse                                  # see what's available"
          puts "  sketch!                                 # back to sketch mode"
        end
        puts ""
        self
      end

      # Switch back to sketch mode, tearing down the playground.
      #
      # Sets mode to :sketch and nils out the playground reference,
      # allowing the compiled domain module to be garbage collected.
      #
      # @return [Session] self
      def sketch!
        @mode = :sketch
        @playground = nil
        puts "Back to sketch mode"
        self
      end

      # Return all events captured during play mode.
      #
      # @return [Array] list of event objects recorded by the playground
      # @raise [RuntimeError] if not in play mode
      def events
        ensure_play_mode!
        @playground.events
      end

      # Return events of a specific type by class name.
      #
      # @param type_name [String] the short event class name (e.g. "CreatedPizza")
      # @return [Array] matching event objects
      # @raise [RuntimeError] if not in play mode
      def events_of(type_name)
        ensure_play_mode!
        @playground.events_of(type_name)
      end

      # List all available commands in the compiled domain.
      #
      # @return [Array<String>] command descriptions with signatures and event names
      # @raise [RuntimeError] if not in play mode
      def commands
        ensure_play_mode!
        @playground.commands
      end

      # Print a numbered history of all events that have occurred.
      #
      # @return [nil]
      # @raise [RuntimeError] if not in play mode
      def history
        ensure_play_mode!
        @playground.history
      end

      # Clear all events and repository data in the playground.
      #
      # @return [void]
      # @raise [RuntimeError] if not in play mode
      def reset!
        ensure_play_mode!
        @playground.reset!
      end

      private

      # Guard that raises unless the session is in play mode.
      #
      # @raise [RuntimeError] if not in play mode
      # @return [void]
      def ensure_play_mode!
        raise "Not in play mode. Call session.play! first." unless play?
      end
    end
  end
end
