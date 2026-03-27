module ComplianceDomain
  module Ports
    module RegulatoryFrameworkRepository
      def find(id)
        raise NotImplementedError, "#{self.class}#find not implemented"
      end

      def save(regulatory_framework)
        raise NotImplementedError, "#{self.class}#save not implemented"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end
