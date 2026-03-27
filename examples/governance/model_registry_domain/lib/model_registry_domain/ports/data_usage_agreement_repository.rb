module ModelRegistryDomain
  module Ports
    module DataUsageAgreementRepository
      def find(id)
        raise NotImplementedError, "#{self.class}#find not implemented"
      end

      def save(data_usage_agreement)
        raise NotImplementedError, "#{self.class}#save not implemented"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end
