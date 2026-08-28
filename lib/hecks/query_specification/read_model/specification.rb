require_relative "../common/options"

module Hecks
  module QuerySpecification
    module ReadModel
      class Specification < Common::Options
        attr_reader :joins

        def initialize(joins: [], **)
          super(**)
          @joins = joins
        end

        def to_h = options_to_h.merge(joins: @joins)
      end
    end
  end
end
