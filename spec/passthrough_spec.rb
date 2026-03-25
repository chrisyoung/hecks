require "spec_helper"

RSpec.describe "Passthrough attributes on commands" do
  describe "DSL: passthrough declaration" do
    it "stores passthrough fields on the command IR" do
      domain = Hecks.domain("T") do
        aggregate("Model") do
          attribute :name, String
          attribute :model_id, String

          command("SubmitAssessment") do
            attribute :assessment_id, String
            passthrough :model_id
          end
        end
      end

      cmd = domain.aggregates.first.commands.first
      expect(cmd.passthroughs).to eq([:model_id])
    end

    it "supports multiple passthrough fields" do
      domain = Hecks.domain("T") do
        aggregate("Model") do
          attribute :name, String
          attribute :model_id, String
          attribute :version, Integer

          command("SubmitAssessment") do
            attribute :assessment_id, String
            passthrough :model_id, :version
          end
        end
      end

      cmd = domain.aggregates.first.commands.first
      expect(cmd.passthroughs).to eq([:model_id, :version])
    end

    it "defaults to empty passthroughs" do
      domain = Hecks.domain("T") do
        aggregate("A") do
          attribute :n, String
          command("CreateA") { attribute :n, String }
        end
      end

      cmd = domain.aggregates.first.commands.first
      expect(cmd.passthroughs).to eq([])
    end
  end

  describe "Event inference includes passthrough fields" do
    it "adds passthrough fields to the inferred event" do
      domain = Hecks.domain("T") do
        aggregate("Model") do
          attribute :name, String
          attribute :model_id, String

          command("SubmitAssessment") do
            attribute :assessment_id, String
            passthrough :model_id
          end
        end
      end

      event = domain.aggregates.first.events.first
      attr_names = event.attributes.map(&:name)
      expect(attr_names).to include(:assessment_id)
      expect(attr_names).to include(:model_id)
    end

    it "does not duplicate if passthrough field is also a command attribute" do
      domain = Hecks.domain("T") do
        aggregate("Model") do
          attribute :name, String
          attribute :model_id, String

          command("SubmitAssessment") do
            attribute :model_id, String
            passthrough :model_id
          end
        end
      end

      event = domain.aggregates.first.events.first
      model_id_attrs = event.attributes.select { |a| a.name == :model_id }
      expect(model_id_attrs.size).to eq(1)
    end
  end

  describe "CommandGenerator uses existing for passthrough fields" do
    it "generates existing.field_name for passthrough attributes" do
      agg_attrs = [
        Hecks::DomainModel::Structure::Attribute.new(name: :id, type: String),
        Hecks::DomainModel::Structure::Attribute.new(name: :model_id, type: String),
        Hecks::DomainModel::Structure::Attribute.new(name: :score, type: Integer),
      ]
      aggregate = Hecks::DomainModel::Structure::Aggregate.new(
        name: "Assessment", attributes: agg_attrs
      )
      command = Hecks::DomainModel::Behavior::Command.new(
        name: "SubmitAssessment",
        attributes: [
          Hecks::DomainModel::Structure::Attribute.new(name: :assessment_id, type: String),
          Hecks::DomainModel::Structure::Attribute.new(name: :score, type: Integer),
        ],
        passthroughs: [:model_id]
      )
      event = Hecks::DomainModel::Behavior::DomainEvent.new(
        name: "SubmittedAssessment",
        attributes: command.attributes
      )
      gen = Hecks::Generators::Domain::CommandGenerator.new(
        command, domain_module: "TestDomain",
        aggregate_name: "Assessment", aggregate: aggregate, event: event
      )
      code = gen.generate

      expect(code).to include("model_id: existing.model_id")
      expect(code).to include("score: score")
    end
  end
end
