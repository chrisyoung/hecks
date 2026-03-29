# Hecks::Runtime::ConstantHoisting
#
# Promotes aggregate classes to top-level Object constants and tracks
# them on the domain module for later cleanup via unload!
#
module Hecks
  class Runtime
      module ConstantHoisting
        private

        def hoist_constants
          hoisted = []
          @domain.aggregates.each do |agg|
            klass = @mod.const_get(agg.name)
            silence_warnings { Object.const_set(agg.name, klass) }
            hoisted << agg.name.to_sym
          end

          # Store hoisted names on the domain module for unload!
          mod = @mod
          mod_name = @mod.name.to_sym
          mod.define_singleton_method(:unload!) do
            hoisted.each { |name| Hecks::Utils.remove_constant(name) }
            Hecks::Utils.remove_constant(mod_name)
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
