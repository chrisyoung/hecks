require "spec_helper"

RSpec.describe "World Goals :sustainability validation rule" do
  describe "Sustainability validator" do
    it "warns about creation commands without cleanup paths" do
      domain = Hecks.domain "Sustainability" do
        world_goals :sustainability
        aggregate "Session" do
          attribute :token, String
          command "CreateSession" do
            attribute :token, String
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      warnings = validator.warnings
      expect(warnings).to include(/Sustainability.*Session.*creation commands.*no corresponding cleanup/)
    end

    it "does not warn when creation has matching delete command" do
      domain = Hecks.domain "ProperCleanup" do
        world_goals :sustainability
        aggregate "Session" do
          attribute :token, String
          command "CreateSession" do
            attribute :token, String
          end
          command "DeleteSession" do
            attribute :token, String
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Sustainability.*Session/)
    end

    it "detects various creation command patterns" do
      domain = Hecks.domain "CreationPatterns" do
        world_goals :sustainability
        aggregate "Resource" do
          command "Create" do end
          command "Add" do end
          command "Register" do end
          command "Allocate" do end
          command "Open" do end
          command "Start" do end
          command "Spawn" do end
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      warnings = validator.warnings
      expect(warnings).to include(/Sustainability.*Resource.*creation commands/)
    end

    it "detects various cleanup command patterns" do
      domain = Hecks.domain "CleanupPatterns" do
        world_goals :sustainability
        aggregate "Resource" do
          command "Create" do end
          command "Delete" do end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Sustainability.*Resource/)
    end

    it "recognizes Archive as cleanup" do
      domain = Hecks.domain "ArchiveCleanup" do
        world_goals :sustainability
        aggregate "Document" do
          command "CreateDocument" do end
          command "ArchiveDocument" do end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Sustainability.*Document/)
    end

    it "recognizes Expire as cleanup" do
      domain = Hecks.domain "ExpireCleanup" do
        world_goals :sustainability
        aggregate "Token" do
          command "GenerateToken" do end
          command "ExpireToken" do end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Sustainability.*Token/)
    end

    it "does not warn when no creation commands present" do
      domain = Hecks.domain "NoCreation" do
        world_goals :sustainability
        aggregate "Observer" do
          attribute :status, String
          command "UpdateStatus" do
            attribute :status, String
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      warnings = validator.warnings
      expect(warnings).not_to include(/Sustainability/)
    end

    it "does not warn when sustainability goal is not declared" do
      domain = Hecks.domain "NoSustainabilityGoal" do
        aggregate "Session" do
          attribute :token, String
          command "CreateSession" do
            attribute :token, String
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      warnings = validator.warnings
      expect(warnings).not_to include(/Sustainability/)
    end
  end
end
