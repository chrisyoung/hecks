# Hecks::Runtime::ConstantHoisting
#
# Mixin that promotes aggregate classes from the domain module
# namespace into the top-level Object namespace so they can be
# referenced without the module prefix (e.g. Pizza instead of
# PizzaDomain::Pizza).
#
#   class Runtime
#     include ConstantHoisting
#   end
#
module Hecks
  class Runtime
      # Promotes aggregate classes from the domain module namespace (e.g.,
      # +PizzaDomain::Pizza+) to top-level Object constants (e.g., +Pizza+).
      # This allows application code to reference aggregates without the
      # domain module prefix, providing a cleaner API.
      #
      # Warning suppression is used because redefining a constant that already
      # exists at the top level would otherwise produce a Ruby warning.
      module ConstantHoisting
        private

        # Iterates over all aggregates in the domain and sets each one as a
        # top-level constant on Object. For example, if the domain module is
        # +PizzaDomain+ and it has a +Pizza+ aggregate, this creates +::Pizza+
        # pointing to +PizzaDomain::Pizza+.
        #
        # @return [void]
        def hoist_constants
          @domain.aggregates.each do |agg|
            klass = @mod.const_get(agg.name)
            silence_warnings { Object.const_set(agg.name, klass) }
          end
        end

        # Temporarily suppresses Ruby warnings by setting +$VERBOSE+ to nil.
        # Restores the original value after the block executes, even if an
        # exception is raised.
        #
        # @yield block to execute with warnings suppressed
        # @return [Object] the return value of the block
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
