module ModelRegistryDomain
  class DataUsageAgreement
    module Commands
      class CreateAgreement
        include Hecks::Command
        emits "CreatedAgreement"

        attr_reader :model_id
        attr_reader :data_source
        attr_reader :purpose
        attr_reader :consent_type

        def initialize(
          model_id: nil,
          data_source: nil,
          purpose: nil,
          consent_type: nil
        )
          @model_id = model_id
          @data_source = data_source
          @purpose = purpose
          @consent_type = consent_type
        end

        def call
          DataUsageAgreement.new(
            model_id: model_id,
            data_source: data_source,
            purpose: purpose,
            consent_type: consent_type,
            status: "draft"
          )
        end
      end
    end
  end
end
