module IdentityDomain
  module Ports
    module StakeholderRepository
      def find(id)
        raise NotImplementedError, "#{self.class}#find not implemented"
      end

      def save(stakeholder)
        raise NotImplementedError, "#{self.class}#save not implemented"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end
