# Hecks::Generators::Domain::AggregateGenerator::InvariantGeneration
#
# Mixin that generates the check_invariants! method and INVARIANTS constant.
# Converts DSL invariant blocks into runtime proc-based checks. Part of
# Generators::Domain, mixed into AggregateGenerator.
#
#   class AggregateGenerator
#     include InvariantGeneration
#   end
#
module Hecks
  module Generators
    module Domain
      class AggregateGenerator
        module InvariantGeneration
          private

          def invariant_lines
            if @aggregate.invariants.empty?
              return ["    def check_invariants!; end"]
            end

            lines = []
            lines << "    INVARIANTS = {"
            @aggregate.invariants.each do |inv|
              lines << "      #{inv.message.inspect} => #{source_from_block(inv.block)},"
            end
            lines << "    }.freeze"
            lines << ""
            lines << "    def check_invariants!"
            @aggregate.invariants.each do |inv|
              lines << "      raise InvariantError, #{inv.message.inspect} unless instance_eval(&INVARIANTS[#{inv.message.inspect}])"
            end
            lines << "    end"
            lines
          end

          def source_from_block(block)
            "proc { #{Hecks::Utils.block_source(block)} }"
          end
        end
      end
    end
  end
end
