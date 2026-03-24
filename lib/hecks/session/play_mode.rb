# Hecks::Session::PlayMode
#
# Session mixin for play-mode: executing commands against a live compiled
# domain and inspecting events. Part of the Session layer -- delegates to
# Playground for actual execution.
#
#   session.play!
#   session.execute("CreatePizza", name: "Margherita")
#   session.events
#   session.history
#   session.define!   # back to define mode
#
module Hecks
  class Session
    module PlayMode
      # Switch to play mode - compiles domain and lets you work with live objects
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
        puts "Entering play mode"
        puts ""
        puts "  commands                                # list available commands"
        puts "  execute(\"CreatePizza\", name: \"Pepperoni\")"
        puts "  events / history / reset!"
        puts "  define!                                 # back to define mode"
        puts ""
        self
      end

      # Switch back to define mode
      def define!
        @mode = :build
        @playground = nil
        puts "Back to define mode"
        self
      end
      alias_method :build!, :define!

      # Play mode: execute a command
      def execute(command_name, **attrs)
        ensure_play_mode!
        @playground.execute(command_name, **attrs)
      end

      # Play mode: list all events
      def events
        ensure_play_mode!
        @playground.events
      end

      # Play mode: get events of a specific type
      def events_of(type_name)
        ensure_play_mode!
        @playground.events_of(type_name)
      end

      # Play mode: list available commands
      def commands
        ensure_play_mode!
        @playground.commands
      end

      # Play mode: show event history
      def history
        ensure_play_mode!
        @playground.history
      end

      # Play mode: clear all events
      def reset!
        ensure_play_mode!
        @playground.reset!
      end

      private

      def ensure_play_mode!
        raise "Not in play mode. Call session.play! first." unless play?
      end
    end
  end
end
