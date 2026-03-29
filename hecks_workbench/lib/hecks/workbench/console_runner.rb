require_relative "console_runner/constant_hoister"

module Hecks
  class Workbench
    # Hecks::Workbench::ConsoleRunner
    #
    # Interactive IRB workbench for domain modeling. Delegates workbench
    # methods and hoists constants so users can type `Pizza.title String`
    # directly in the REPL.
    #
    #   ConsoleRunner.new(name: "Pizzas").run
    #
    class ConsoleRunner
      include HecksTemplating::NamingHelpers
      include ConstantHoister

    def initialize(name: nil)
      @name = name
    end

    # Delegate workbench methods for direct REPL access
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

    def aggregate(name, &block)
      is_new = !@workbench.aggregate_builders.key?(domain_constant_name(name))
      handle = @workbench.aggregate(name, &block)
      hoist_aggregate(domain_constant_name(name).to_sym, handle)
      puts "#{domain_constant_name(name)} aggregate created" if is_new && !block
      handle
    end

    def extend(name, **kwargs)
      @workbench.extend(name, **kwargs)
    end

    def play!
      result = @workbench.play!
      if @workbench.play? && @workbench.playground
        mod_name = domain_module_name(@workbench.name)
        if Object.const_defined?(mod_name)
          hoist_domain_constants(Object.const_get(mod_name))
        end
      end
      result
    end

    def sketch!
      unhoist_all
      @workbench.sketch!
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
      mode = @workbench&.play? ? "play" : "sketch"
      name = @workbench&.name&.downcase || "scratch"
      "hecks(#{name} #{mode})"
    end

    def to_s = inspect

    def run
      require "irb"
      @workbench = setup_session
      print_help
      launch_irb
    end

    private

    def launch_irb
      history_file = File.join(Dir.home, ".hecks_history")
      IRB.setup(nil)
      IRB.conf[:HISTORY_FILE] = history_file
      IRB.conf[:SAVE_HISTORY] = 1000
      load_history(history_file)

      workspace = IRB::WorkSpace.new(binding)
      irb = IRB::Irb.new(workspace)
      IRB.conf[:MAIN_CONTEXT] = irb.context

      @show_backtrace = false
      install_exception_handler(irb)
      catch(:IRB_EXIT) { irb.eval_input }
      save_history(history_file)
    end

    def load_history(path)
      return unless defined?(Reline) && File.exist?(path)
      File.readlines(path, chomp: true).each { |line| Reline::HISTORY << line } rescue nil
    end

    def save_history(path)
      return unless defined?(Reline)
      File.open(path, "w") { |f| Reline::HISTORY.last(1000).each { |line| f.puts(line) } }
    end

    def install_exception_handler(irb)
      runner = self
      irb.define_singleton_method(:handle_exception) do |exc|
        if runner.instance_variable_get(:@show_backtrace)
          super(exc)
        else
          puts "#{exc.class}: #{exc.message}"
        end
      end
    end

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
