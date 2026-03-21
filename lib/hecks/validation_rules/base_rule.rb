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
