module IdentityDomain
  class Stakeholder
    module Commands
      class RegisterStakeholder
        include Hecks::Command
        emits "RegisteredStakeholder"

        attr_reader :name
        attr_reader :email
        attr_reader :role
        attr_reader :team

        def initialize(
          name: nil,
          email: nil,
          role: nil,
          team: nil
        )
          @name = name
          @email = email
          @role = role
          @team = team
        end

        def call
          Stakeholder.new(
            name: name,
            email: email,
            role: role,
            team: team,
            status: "active"
          )
        end
      end
    end
  end
end
