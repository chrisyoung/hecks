require "spec_helper"

RSpec.describe "Policy defaults" do
  describe "DSL and IR" do
    it "stores defaults hash on the Policy IR" do
      domain = Hecks.domain "Auditing" do
        aggregate "Model" do
          attribute :name, String
          command "RegisterModel" do
            attribute :name, String
          end
        end

        aggregate "AuditEntry" do
          attribute :entity_type, String
          attribute :action, String
          attribute :entity_id, String

          command "RecordEntry" do
            attribute :entity_type, String
            attribute :action, String
            attribute :entity_id, String
          end
        end

        policy "AuditRegistration" do
          on "RegisteredModel"
          trigger "RecordEntry"
          map model_id: :entity_id
          defaults entity_type: "AiModel", action: "registered"
        end
      end

      pol = domain.policies.first
      expect(pol.defaults).to eq({ entity_type: "AiModel", action: "registered" })
    end

    it "defaults to empty hash when no defaults declared" do
      domain = Hecks.domain "Defaults" do
        aggregate "Task" do
          attribute :name, String
          command "CreateTask" do
            attribute :name, String
          end
        end

        policy "Simple" do
          on "CreatedTask"
          trigger "CreateTask"
        end
      end

      pol = domain.policies.first
      expect(pol.defaults).to eq({})
    end
  end

  describe "runtime" do
    it "injects defaults into the triggered command attrs" do
      domain = Hecks.domain "AuditDomain" do
        aggregate "Model" do
          attribute :name, String
          command "RegisterModel" do
            attribute :name, String
          end
        end

        aggregate "Entry" do
          attribute :entity_type, String
          attribute :action, String
          attribute :name, String

          command "RecordEntry" do
            attribute :entity_type, String
            attribute :action, String
            attribute :name, String
          end
        end

        policy "AuditRegistration" do
          on "RegisteredModel"
          trigger "RecordEntry"
          map name: :name
          defaults entity_type: "AiModel", action: "registered"
        end
      end

      app = Hecks.load(domain, force: true)
      app.run("RegisterModel", name: "GPT-5")

      record_event = app.events.find { |e| e.class.name.split("::").last == "RecordedEntry" }
      expect(record_event).not_to be_nil
      expect(record_event.entity_type).to eq("AiModel")
      expect(record_event.action).to eq("registered")
      expect(record_event.name).to eq("GPT-5")
    end

    it "defaults override mapped values for the same key" do
      domain = Hecks.domain "OverrideDomain" do
        aggregate "Source" do
          attribute :status, String
          command "Act" do
            attribute :status, String
          end
        end

        aggregate "Target" do
          attribute :status, String
          command "React" do
            attribute :status, String
          end
        end

        policy "Override" do
          on "Acted"
          trigger "React"
          map status: :status
          defaults status: "forced"
        end
      end

      app = Hecks.load(domain, force: true)
      app.run("Act", status: "original")

      react_event = app.events.find { |e| e.class.name.split("::").last == "Reacted" }
      expect(react_event).not_to be_nil
      expect(react_event.status).to eq("forced")
    end
  end
end
