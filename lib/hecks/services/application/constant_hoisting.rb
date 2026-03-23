# Hecks::Services::Application::ConstantHoisting
#
# Mixin that promotes aggregate classes from the domain module
# namespace into the top-level Object namespace so they can be
# referenced without the module prefix (e.g. Pizza instead of
# PizzaDomain::Pizza).
#
#   class Application
#     include ConstantHoisting
#   end
#
module Hecks
  module Services
    class Application
      module ConstantHoisting
        private

        def hoist_constants
          @domain.aggregates.each do |agg|
            klass = @mod.const_get(agg.name)
            silence_warnings { Object.const_set(agg.name, klass) }
          end
        end

        def silence_warnings
          old = $VERBOSE
          $VERBOSE = nil
          yield
        ensure
          $VERBOSE = old
        end
      end
    end
  end
end
