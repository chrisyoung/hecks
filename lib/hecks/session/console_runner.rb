# Hecks::Session::ConsoleRunner
#
# Launches an interactive IRB session pre-configured with a Hecks Session.
# Loads hecks_domain.rb if present, otherwise starts a new empty session.
#
#   ConsoleRunner.new(name: "Pizzas").run
#
module Hecks
  class Session
    class ConsoleRunner
    def initialize(name: nil)
      @name = name
    end

    # Delegate session methods so users can type `aggregate("Cat")`
    # instead of `session.aggregate("Cat")` in the REPL.
    %i[
      aggregates remove add_verb active_hecks!
      validate preview describe build save to_dsl status browse
      play! sketch! execute events events_of commands history reset!
    ].each do |m|
      define_method(m) do |*args, **kwargs, &block|
        @session.send(m, *args, **kwargs, &block)
      end
    end

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

    # Override play! to hoist domain constants into ConsoleRunner's scope
    # so typing `Cat` in play mode resolves to ScratchDomain::Cat.
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

    # Remove hoisted constants and switch back to sketch mode
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

    def backtrace!
      @show_backtrace = true
      puts "Backtrace on"
      nil
    end

    def quiet!
      @show_backtrace = false
      puts "Backtrace off"
      nil
    end

    def help
      print_help
      nil
    end

    def inspect
      mode = @session&.play? ? "play" : "sketch"
      name = @session&.name&.downcase || "scratch"
      "hecks(#{name} #{mode})"
    end

    def to_s
      inspect
    end

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
