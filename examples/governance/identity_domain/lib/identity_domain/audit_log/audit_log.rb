require 'hecks/mixins/model'

module IdentityDomain
  class AuditLog
    include Hecks::Model

    attribute :entity_type
    attribute :entity_id
    attribute :action
    attribute :actor_id
    attribute :details
    attribute :timestamp

    private

    def validate!
      raise ValidationError.new("entity_type can't be blank", field: :entity_type, rule: :presence) if entity_type.nil? || (entity_type.respond_to?(:empty?) && entity_type.empty?)
      raise ValidationError.new("action can't be blank", field: :action, rule: :presence) if action.nil? || (action.respond_to?(:empty?) && action.empty?)
    end
  end
end
