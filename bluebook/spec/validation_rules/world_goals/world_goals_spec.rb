require "spec_helper"

RSpec.describe "World Goals advisory validators" do
  def validate(domain)
    validator = Hecks::Validator.new(domain)
    validator.valid?
    [validator.valid?, validator.errors, validator.warnings]
  end

  describe "no goals declared" do
    it "produces no warnings" do
      domain = Hecks.domain "Clean" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      _valid, _errors, warnings = validate(domain)
      expect(warnings.grep(/Equity|Sustainability/)).to be_empty
    end
  end

  describe ":equity" do
    it "warns when only one actor role is defined" do
      domain = Hecks.domain "Monopoly" do
        world_goals :equity
        actor "Admin"
        aggregate "Config" do
          attribute :key, String
          command "UpdateConfig" do
            attribute :key, String
          end
        end
      end

      valid, _errors, warnings = validate(domain)
      expect(valid).to be true
      expect(warnings).to include(/Equity.*only one actor role 'Admin'/)
    end

    it "does not warn when multiple actor roles exist" do
      domain = Hecks.domain "Balanced" do
        world_goals :equity
        actor "Admin"
        actor "Reviewer"
        aggregate "Config" do
          attribute :key, String
          command "UpdateConfig" do
            attribute :key, String
          end
        end
      end

      _valid, _errors, warnings = validate(domain)
      expect(warnings.grep(/Equity/)).to be_empty
    end

    it "does not warn when no actors are defined" do
      domain = Hecks.domain "NoActors" do
        world_goals :equity
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      _valid, _errors, warnings = validate(domain)
      expect(warnings.grep(/Equity/)).to be_empty
    end
  end

  describe ":sustainability" do
    it "warns when an aggregate has no lifecycle" do
      domain = Hecks.domain "Ephemeral" do
        world_goals :sustainability
        aggregate "Report" do
          attribute :title, String
          command "CreateReport" do
            attribute :title, String
          end
        end
      end

      valid, _errors, warnings = validate(domain)
      expect(valid).to be true
      expect(warnings).to include(/Sustainability.*Report.*no lifecycle/)
    end

    it "does not warn when aggregates have lifecycles" do
      domain = Hecks.domain "Durable" do
        world_goals :sustainability
        aggregate "Report" do
          attribute :title, String
          attribute :status, String

          lifecycle :status, default: "draft" do
            transition "PublishReport" => "published"
            transition "ArchiveReport" => "archived"
          end

          command "CreateReport" do
            attribute :title, String
          end
          command "PublishReport" do
            attribute :title, String
          end
          command "ArchiveReport" do
            attribute :title, String
          end
        end
      end

      _valid, _errors, warnings = validate(domain)
      expect(warnings.grep(/Sustainability/)).to be_empty
    end
  end

  describe "world_goals never produce errors" do
    it "domain remains valid even when goals are violated" do
      domain = Hecks.domain "AllGoals" do
        world_goals :equity, :sustainability
        actor "Solo"
        aggregate "Temp" do
          attribute :name, String
          command "CreateTemp" do
            attribute :name, String
          end
        end
      end

      valid, errors, warnings = validate(domain)
      expect(valid).to be true
      expect(errors).to be_empty
      expect(warnings).to include(/Equity/)
      expect(warnings).to include(/Sustainability/)
    end
  end
end
