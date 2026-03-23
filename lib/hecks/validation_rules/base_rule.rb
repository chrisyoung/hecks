# Hecks::ValidationRules::BaseRule
#
# Abstract base class for all domain validation rules. Subclasses implement
# #errors to return an array of error message strings for the given domain.
#
#   class MyRule < BaseRule
#     def errors
#       # return [] or ["error message", ...]
#     end
#   end
#
module Hecks
  module ValidationRules
    class BaseRule
      def initialize(domain)
        @domain = domain
      end

      def errors
        raise NotImplementedError
      end
    end
  end
end
