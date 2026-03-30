module Hecks
  module DSL
    class DomainBuilder

      # Hecks::DSL::DomainBuilder::AclBuilder
      #
      # Collects translations for an anti-corruption layer.
      #
      #   anti_corruption_layer "Billing" do
      #     translate "Invoice", billing_id: :invoice_number
      #   end
      #
      class AclBuilder
        def initialize(acl)
          @acl = acl
        end

        def translate(type, **mappings)
          @acl[:translations] << { type: type.to_s, mappings: mappings }
        end
      end

      # Hecks::DSL::DomainBuilder::SagaBuilder
      #
      # Collects steps and compensations for a saga.
      #
      #   saga "ModelOnboarding" do
      #     step "RegisterModel", on_success: "ClassifyRisk"
      #     compensation "SuspendModel"
      #   end
      #
      class SagaBuilder
        def initialize(saga)
          @saga = saga
        end

        def step(command, on_success: nil, on_failure: nil)
          @saga[:steps] << { command: command, on_success: on_success, on_failure: on_failure }
        end

        def compensation(command)
          @saga[:compensations] << command
        end
      end

      # Hecks::DSL::DomainBuilder::GlossaryBuilder
      #
      # Collects term preference rules for ubiquitous language enforcement.
      #
      #   glossary do
      #     prefer "stakeholder", not: ["user", "person"]
      #   end
      #
      class GlossaryBuilder
        def initialize(rules)
          @rules = rules
        end

        def prefer(term, not: [])
          banned = binding.local_variable_get(:not)
          @rules << { preferred: term, banned: banned }
        end
      end

      # Hecks::DSL::DomainBuilder::ModuleBuilder
      #
      # Delegates aggregate creation to the parent domain builder
      # while tracking which aggregates belong to this module.
      #
      #   domain_module "PolicyManagement" do
      #     aggregate "GovernancePolicy" do ... end
      #   end
      #
      class ModuleBuilder
        attr_reader :aggregate_names

        def initialize(name, parent)
          @name = name
          @parent = parent
          @aggregate_names = []
        end

        def aggregate(name, description = nil, &block)
          @aggregate_names << name
          @parent.aggregate(name, description, &block)
        end
      end

    end
  end
end
