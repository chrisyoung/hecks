require 'hecks/mixins/model'

module RiskAssessmentDomain
  class Assessment
    class Mitigation
      include Hecks::Model

      attribute :finding_category
      attribute :action
      attribute :status
    end
  end
end
