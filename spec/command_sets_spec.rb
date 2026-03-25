require "spec_helper"

RSpec.describe "Command sets declaration" do
  describe "DSL and IR" do
    it "stores sets hash on the Command IR" do
      domain = Hecks.domain "T" do
        aggregate "Review" do
          attribute :status, String
          attribute :outcome, String

          command "ApproveReview" do
            attribute :review_id, String
            sets status: "approved", outcome: "approved"
          end
        end
      end

      cmd = domain.aggregates.first.commands.first
      expect(cmd.sets).to eq({ status: "approved", outcome: "approved" })
    end

    it "defaults to empty hash when no sets declared" do
      domain = Hecks.domain "T" do
        aggregate "Thing" do
          attribute :name, String
          command "CreateThing" do
            attribute :name, String
          end
        end
      end

      cmd = domain.aggregates.first.commands.first
      expect(cmd.sets).to eq({})
    end
  end

  describe "code generation" do
    FakeEvent = Struct.new(:name, keyword_init: true)

    it "injects sets values into create constructor args" do
      domain = Hecks.domain "T" do
        aggregate "Review" do
          attribute :status, String
          attribute :outcome, String
          attribute :review_id, String

          command "CreateReview" do
            attribute :review_id, String
            sets status: "pending", outcome: "none"
          end
        end
      end

      agg = domain.aggregates.first
      cmd = agg.commands.first
      event = FakeEvent.new(name: cmd.inferred_event_name)

      gen = Hecks::Generators::Domain::CommandGenerator.new(
        cmd, domain_module: "TDomain", aggregate_name: "Review", aggregate: agg, event: event
      )
      code = gen.generate

      expect(code).to include('status: "pending"')
      expect(code).to include('outcome: "none"')
    end

    it "injects sets values into update constructor args" do
      domain = Hecks.domain "T" do
        aggregate "Review" do
          attribute :status, String
          attribute :outcome, String

          command "ApproveReview" do
            attribute :review_id, String
            sets status: "approved", outcome: "approved"
          end
        end
      end

      agg = domain.aggregates.first
      cmd = agg.commands.first
      event = FakeEvent.new(name: cmd.inferred_event_name)

      gen = Hecks::Generators::Domain::CommandGenerator.new(
        cmd, domain_module: "TDomain", aggregate_name: "Review", aggregate: agg, event: event
      )
      code = gen.generate

      expect(code).to include('status: "approved"')
      expect(code).to include('outcome: "approved"')
    end
  end

  describe "runtime" do
    it "applies sets values to the created aggregate" do
      domain = Hecks.domain "SetRuntime" do
        aggregate "Review" do
          attribute :status, String
          attribute :reviewer, String

          command "CreateReview" do
            attribute :reviewer, String
            sets status: "pending"
          end
        end
      end

      app = Hecks.load(domain, force: true)
      review = SetRuntimeDomain::Review.create(reviewer: "Alice")

      expect(review.status).to eq("pending")
      expect(review.reviewer).to eq("Alice")
    end

    it "applies sets values on update commands" do
      domain = Hecks.domain "SetUpdate" do
        aggregate "Review" do
          attribute :status, String
          attribute :reviewer, String

          command "CreateReview" do
            attribute :reviewer, String
          end

          command "ApproveReview" do
            attribute :review_id, String
            sets status: "approved"
          end
        end
      end

      app = Hecks.load(domain, force: true)
      review = SetUpdateDomain::Review.create(reviewer: "Alice")
      updated = SetUpdateDomain::Review.approve(review_id: review.id)

      expect(updated.status).to eq("approved")
    end
  end
end
