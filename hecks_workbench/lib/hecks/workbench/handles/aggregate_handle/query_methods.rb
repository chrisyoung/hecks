# Hecks::Workbench::AggregateHandle::QueryMethods
#
# Query and scope handle methods with REPL feedback.
#
module Hecks
  class Workbench
    class AggregateHandle
      module QueryMethods
        def query(name, &block)
          @builder.query(name, &block)
          puts "#{name} query added to #{@name}"
          self
        end

        def scope(name, conditions = nil, &block)
          @builder.scope(name, conditions, &block)
          puts "#{name} scope added to #{@name}"
          self
        end
      end
    end
  end
end
