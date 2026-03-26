# Hecks::Session::ConsoleRunner
#
# Launches an interactive IRB session pre-configured with a Hecks Session.
# Loads hecks_domain.rb if present, otherwise starts a new empty session.
#
# The ConsoleRunner acts as the top-level binding for the IRB workspace,
# delegating session methods (aggregate, validate, play!, etc.) so users
# can call them directly without a +session.+ prefix. When aggregates are
# defined, their handles are hoisted as constants on ConsoleRunner so that
# +Pizza.attr :name, String+ works naturally. In play mode, domain module
# constants are also hoisted so +Pizza.create(...)+ resolves correctly.
#
# Backtrace display is suppressed by default for cleaner REPL output;
# call +backtrace!+ to enable full traces and +quiet!+ to suppress again.
#
#   ConsoleRunner.new(name: "Pizzas").run
#
module Hecks
  class Session
    class ConsoleRunner
    # Create a new ConsoleRunner.
    #
    # @param name [String, nil] domain name to start with; if nil, attempts to
    #   load hecks_domain.rb or falls back to "MyDomain"
    def initialize(name: nil)
      @name = name
    end

    # Delegate session methods so users can type `aggregate("Cat")`
    # instead of `session.aggregate("Cat")` in the REPL.
    %i[
      aggregates remove add_verb active_hecks!
      validate preview describe build save to_dsl status browse
      play! sketch! events events_of commands history reset!
    ].each do |m|
      define_method(m) do |*args, **kwargs, &block|
        @session.send(m, *args, **kwargs, &block)
      end
    end

    # Define or retrieve an aggregate, hoisting the handle as a constant.
    #
    # Delegates to Session#aggregate and then sets the returned handle as a
    # constant on ConsoleRunner (e.g. +Cat+) so users can interact with it
    # by name in the REPL. Duplicate constant definitions are skipped.
    #
    # @param name [String] the aggregate name
    # @yield optional block passed through to Session#aggregate
    # @return [AggregateHandle] the handle for the aggregate
    def aggregate(name, &block)
      handle = @session.aggregate(name, &block)
      const_name = Hecks::Utils.sanitize_constant(name).to_sym
      @hoisted_handle_constants ||= []
      unless self.class.const_defined?(const_name, false)
        self.class.const_set(const_name, handle)
        @hoisted_handle_constants << const_name
      end
      handle
    end

    # Switch to play mode and hoist domain constants into ConsoleRunner scope.
    #
    # Delegates to Session#play! to compile the domain, then copies all
    # constants from the generated domain module (e.g. PizzasDomain::Pizza)
    # into ConsoleRunner so they are accessible by short name in the REPL.
    #
    # @return [Session] the session (from Session#play!)
    def play!
      result = @session.play!
      if @session.play? && @session.playground
        @hoisted_constants = []
        mod_name = @session.name.gsub(/\s+/, "") + "Domain"
        if Object.const_defined?(mod_name)
          mod = Object.const_get(mod_name)
          mod.constants.each do |const_name|
            unless self.class.const_defined?(const_name, false)
              self.class.const_set(const_name, mod.const_get(const_name))
              @hoisted_constants << const_name
            end
          end
        end
      end
      result
    end

    # Switch back to sketch mode, removing all hoisted constants.
    #
    # Removes both aggregate handle constants and domain module constants
    # that were hoisted during aggregate definition and play mode, then
    # delegates to Session#sketch! to reset the session mode.
    #
    # @return [Session] the session (from Session#sketch!)
    def sketch!
      [@hoisted_constants, @hoisted_handle_constants].compact.each do |list|
        list.each do |const_name|
          self.class.send(:remove_const, const_name) if self.class.const_defined?(const_name, false)
        end
      end
      @hoisted_constants = nil
      @hoisted_handle_constants = nil
      @session.sketch!
    end

    # Enable full backtrace display for errors in the REPL.
    #
    # @return [nil]
    def backtrace!
      @show_backtrace = true
      puts "Backtrace on"
      nil
    end

    # Suppress backtrace display, showing only error messages.
    #
    # @return [nil]
    def quiet!
      @show_backtrace = false
      puts "Backtrace off"
      nil
    end

    # Print help text for available REPL commands.
    #
    # @return [nil]
    def help
      print_help
      nil
    end

    # Return a compact string representation showing mode and domain name.
    #
    # @return [String] e.g. "hecks(pizzas play)"
    def inspect
      mode = @session&.play? ? "play" : "sketch"
      name = @session&.name&.downcase || "scratch"
      "hecks(#{name} #{mode})"
    end

    # Alias for inspect, used by IRB for display.
    #
    # @return [String]
    def to_s
      inspect
    end

    # Launch the interactive IRB session.
    #
    # Sets up the session (from name, hecks_domain.rb, or default), configures
    # IRB with history support and a custom exception handler, then enters
    # the IRB eval loop. History is saved to ~/.hecks_history on exit.
    #
    # @return [void]
    def run
      require "irb"

      @session = setup_session
      print_help

      history_file = File.join(Dir.home, ".hecks_history")

      IRB.setup(nil)
      IRB.conf[:HISTORY_FILE] = history_file
      IRB.conf[:SAVE_HISTORY] = 1000
      # Load prior history into Reline
      if defined?(Reline) && File.exist?(history_file)
        File.readlines(history_file, chomp: true).each { |line| Reline::HISTORY << line } rescue nil
      end

      workspace = IRB::WorkSpace.new(binding)
      irb = IRB::Irb.new(workspace)
      IRB.conf[:MAIN_CONTEXT] = irb.context

      # Suppress backtraces by default — show only error message
      @show_backtrace = false
      runner = self
      irb.define_singleton_method(:handle_exception) do |exc|
        if runner.instance_variable_get(:@show_backtrace)
          super(exc)
        else
          puts "#{exc.class}: #{exc.message}"
        end
      end

      catch(:IRB_EXIT) { irb.eval_input }

      # Save history on exit
      if defined?(Reline)
        File.open(history_file, "w") do |f|
          Reline::HISTORY.last(1000).each { |line| f.puts(line) }
        end
      end
    end

    private

    # Set up the session based on provided name or existing domain file.
    #
    # Priority:
    # 1. If a name was provided to the constructor, create a new session with that name
    # 2. If hecks_domain.rb exists in the current directory, load it and rebuild the session
    # 3. Otherwise, create a default "MyDomain" session
    #
    # @return [Session] the configured session
    def setup_session
      if @name
        session = Hecks.session(@name)
        puts "Started session: #{@name}"
        return session
      end

      if File.exist?("hecks_domain.rb")
        Kernel.load("hecks_domain.rb")
        domain = Hecks.last_domain
        session = Session.new(domain.name)
        domain.aggregates.each do |agg|
          session.aggregate_builders[agg.name] =
            DSL::AggregateRebuilder.from_aggregate(agg)
        end

        puts "Loaded domain from domain.rb: #{domain.name}"
        return session
      end

      session = Hecks.session("MyDomain")
      puts "Started new session: MyDomain"
      session
    end

    # Print the REPL help/welcome message showing available commands.
    #
    # @return [void]
    def print_help
      puts ""
      puts "  aggregate(\"Pizza\")              # creates Pizza constant"
      puts "  Pizza.attr :name                 # add attribute"
      puts "  Pizza.command(\"Create\") { attribute :name, String }"
      puts ""
      puts "  browse                           # system browser"
      puts "  validate / describe / preview"
      puts "  play!                            # enter play mode"
      puts "  sketch!                          # back to sketch mode"
      puts "  save / build"
      puts ""
    end
  end
  end
end
