# Hecks::CustomConcerns
#
# User-defined governance rules that compose extensions. Custom concerns
# extend the built-in world concerns (:transparency, :consent, :privacy,
# :security) with domain-specific governance checks.
#
# Define a custom concern with `Hecks.concern`, then declare it on domains
# alongside world concerns using the `concerns` keyword.
#
#   Hecks.concern :hipaa_compliance do
#     description "HIPAA compliance for healthcare data"
#     requires_extension :pii
#     requires_extension :audit
#     rule "PII must be hidden" do |aggregate|
#       aggregate.attributes.select(&:pii?).all? { |a| !a.visible? }
#     end
#   end
#
module Hecks
  module CustomConcerns
    autoload :Rule,             "hecks/custom_concerns/rule"
    autoload :Concern,          "hecks/custom_concerns/concern"
    autoload :ConcernBuilder,   "hecks/custom_concerns/concern_builder"
    autoload :ConcernRegistry,  "hecks/custom_concerns/concern_registry"
  end
end
