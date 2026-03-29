
module Hecks
  class Workbench
    # Hecks::Workbench::ConsoleRunner
    #
    # Launches an interactive IRB workbench pre-configured with a Hecks Session.
    # Loads hecks_domain.rb if present, otherwise starts a new empty workbench.
    #
    # The ConsoleRunner acts as the top-level binding for the IRB workspace,
    # delegating workbench methods (aggregate, validate, play!, etc.) so users
    # can call them directly without a +workbench.+ prefix. When aggregates are
    # defined, their handles are hoisted as constants on ConsoleRunner so that
    # +Pizza.attr :name, String+ works naturally. In play mode, domain module
    # constants are also hoisted so +Pizza.create(...)+ resolves correctly.
    #
    # Backtrace display is suppressed by default for cleaner REPL output;
    # call +backtrace!+ to enable full traces and +quiet!+ to suppress again.
    #
    #   ConsoleRunner.new(name: "Pizzas").run
    #
    class ConsoleRunner
      include Hecks::NamingHelpers
    # Create a new ConsoleRunner.
    #
    # @param name [String, nil] domain name to start with; if nil, attempts to
    #   load hecks_domain.rb or falls back to "MyDomain"
    def initialize(name: nil)
      @name = name
    end

    # Delegate workbench methods so users can type `aggregate("Cat")`
    # instead of `workbench.aggregate("Cat")` in the REPL.
    %i[
      aggregates remove add_verb active_hecks!
      validate preview describe build save to_dsl status browse
      play! sketch! serve! events events_of commands history reset!
      promote
    ].each do |m|
      define_method(m) do |*args, **kwargs, &block|
        @workbench.send(m, *args, **kwargs, &block)
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
      is_new = !@workbench.aggregate_builders.key?(domain_constant_name(name))
      handle = @workbench.aggregate(name, &block)
      const_name = domain_constant_name(name).to_sym
      @hoisted_handle_constants ||= []
      unless self.class.const_defined?(const_name, false)
        self.class.const_set(const_name, handle)
        @hoisted_handle_constants << const_name
      end
      puts "#{const_name} aggregate created" if is_new && !block
      handle
    end

    # Apply an extension to the live runtime in play mode.
    #
    #   extend :logging
    #   extend :sqlite
    #
    # @param name [Symbol] the extension name
    # @return [Session] self
    def extend(name, **kwargs)
      @workbench.extend(name, **kwargs)
    end

    # Switch to play mode and hoist domain constants into ConsoleRunner scope.
    #
    # Delegates to Session#play! to compile the domain, then copies all
    # constants from the generated domain module (e.g. PizzasDomain::Pizza)
    # into ConsoleRunner so they are accessible by short name in the REPL.
    #
    # @return [Session] the workbench (from Session#play!)
    def play!
      result = @workbench.play!
      if @workbench.play? && @workbench.playground
        @hoisted_constants = []
        mod_name = domain_module_name(@workbench.name)
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
    # delegates to Session#sketch! to reset the workbench mode.
    #
    # @return [Session] the workbench (from Session#sketch!)
    def sketch!
      [@hoisted_constants, @hoisted_handle_constants].compact.each do |list|
        list.each do |const_name|
          self.class.send(:remove_const, const_name) if self.class.const_defined?(const_name, false)
        end
      end
      @hoisted_constants = nil
      @hoisted_handle_constants = nil
      @workbench.sketch!
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
      mode = @workbench&.play? ? "play" : "sketch"
      name = @workbench&.name&.downcase || "scratch"
      "hecks(#{name} #{mode})"
    end

    # Alias for inspect, used by IRB for display.
    #
    # @return [String]
    def to_s
      inspect
    end

    # Launch the interactive IRB workbench.
    #
    # Sets up the workbench (from name, hecks_domain.rb, or default), configures
    # IRB with history support and a custom exception handler, then enters
    # the IRB eval loop. History is saved to ~/.hecks_history on exit.
    #
    # @return [void]
    def run
      require "irb"

      @workbench = setup_session
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

    # Set up the workbench based on provided name or existing domain file.
    #
    # Priority:
    # 1. If a name was provided to the constructor, create a new workbench with that name
    # 2. If hecks_domain.rb exists in the current directory, load it and rebuild the workbench
    # 3. Otherwise, create a default "MyDomain" workbench
    #
    # @return [Session] the configured workbench
    def setup_session
      if @name
        workbench = Hecks.workbench(@name)
        puts "Started workbench: #{@name}"
        return workbench
      end

      if File.exist?("hecks_domain.rb")
        Kernel.load("hecks_domain.rb")
        domain = Hecks.last_domain
        workbench = Session.new(domain.name)
        domain.aggregates.each do |agg|
          workbench.aggregate_builders[agg.name] =
            DSL::AggregateRebuilder.from_aggregate(agg)
        end

        puts "Loaded domain from domain.rb: #{domain.name}"
        return workbench
      end

      workbench = Hecks.workbench("MyDomain")
      puts "Started new workbench: MyDomain"
      workbench
    end

    # Print the REPL help/welcome message showing available commands.
    #
    # @return [void]
    def print_help
      puts ""
      puts "  Post                             # create aggregate"
      puts "  Post.title String                # add attribute"
      puts "  Post.create                      # add command"
      puts "  Post.create.title String         # add attribute to command"
      puts "  Post.lifecycle :status, default: \"draft\""
      puts "  Post.transition \"PublishPost\" => \"published\""
      puts ""
      puts "  play! / sketch!                  # switch modes"
      puts "  save / build"
      puts "  validate / describe / preview / browse"
      puts ""
    end
  end
  end
end
