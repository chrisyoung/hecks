# Hecks::Session::ConsoleRunner
#
# Launches an interactive IRB session pre-configured with a Hecks Session.
# Loads domain.rb if it exists, otherwise starts a new session.
#
#   ConsoleRunner.new(name: "Pizzas").run
#
module Hecks
  class Session
    class ConsoleRunner
    def initialize(name: nil)
      @name = name
    end

    def run
      require "irb"

      session = setup_session
      print_help

      IRB.setup(nil)
      workspace = IRB::WorkSpace.new(binding)
      irb = IRB::Irb.new(workspace)
      IRB.conf[:MAIN_CONTEXT] = irb.context
      irb.eval_input
    end

    private

    def setup_session
      if @name
        session = Hecks.session(@name)
        puts "Started session: #{@name}"
        return session
      end

      if File.exist?("hecks_domain.rb")
        domain = eval(File.read("hecks_domain.rb"), binding, "hecks_domain.rb")
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
      puts "  pizza = session.aggregate(\"Pizza\")"
      puts "  pizza.add_attribute :name, String"
      puts "  pizza.add_command(\"Create\") { attribute :name, String }"
      puts ""
      puts "  session.validate"
      puts "  session.describe"
      puts "  session.preview"
      puts "  session.save      # write domain.rb"
      puts "  session.build     # generate domain gem"
      puts ""
    end
  end
  end
end
