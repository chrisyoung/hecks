# Hecks::DomainModel::Behavior::Workflow
#
# Intermediate representation of a workflow — a conditional multi-step
# command orchestration. Each workflow has a name and an ordered array of
# steps. Steps are either sequential commands (with optional attribute
# mapping) or branches that evaluate a specification to choose a path.
#
#   workflow = Workflow.new(
#     name: "LoanApproval",
#     steps: [
#       { command: "ScoreLoan", mapping: {} },
#       { branch: { spec: "HighRisk", if_steps: [...], else_steps: [...] } }
#     ]
#   )
#
module Hecks
  module DomainModel
    module Behavior
      class Workflow
        attr_reader :name, :steps, :schedule

        def initialize(name:, steps: [], schedule: nil)
          @name = name
          @steps = steps
          @schedule = schedule
        end

        def scheduled?
          !@schedule.nil?
        end
      end
    end
  end
end
