require "spec_helper"
require "tempfile"

# Real dispatch coverage for the two features this PR combines (found
# genuinely inseparable on real-diff read -- see this split's plan file
# for why): `template(from_pm(...))` composition, and saga `for_each:`
# dispatch fan-out.
RSpec.describe "saga template composition and for_each dispatch fan-out" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["saga-template-foreach-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds)
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  describe "template(from_pm(...))" do
    TEMPLATE_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "TemplateGrowth" do
        aggregate "GrowthNote" do
          identified_by { id.value }

          value_object "GrowthNoteId" do
            attribute :value, String
          end

          attribute :id, GrowthNoteId

          command "Open" do
            attribute :id,     GrowthNoteId
            attribute :target, String
            emits "Opened"
          end

          command "Annotate" do
            reference_to GrowthNote
            attribute :text, String, optional: true
            then_set :last_text, to: :text
          end
          attribute :last_text, String
        end

        process_manager "TemplateSaga" do
          correlates_by :"id.value"
          starts_on "Opened"
          ends_on "Annotated"

          state "opening"
          state "opened"

          on "Opened", transition: { "opening" => "opened" } do
            remember target: from_event(:target)
            dispatch "GrowthNote.Annotate",
                     with: { id: :id, text: template("going deeper into %s", from_pm(:target)) }
          end
        end
      end
    BLUEBOOK

    it "composes a literal with a saga-memory value into the dispatched command" do
      runtime = boot(TEMPLATE_SOURCE, "TemplateGrowth") { ::TemplateGrowth::GrowthNote.persisted_by("Memory") }
      runtime.dispatch("TemplateGrowth::GrowthNote.Open", id: { value: "n1" }, target: "the archive")

      expect(TemplateGrowth::GrowthNote.find("n1").last_text.to_s).to eq("going deeper into the archive")
    end
  end

  describe "for_each: dispatch fan-out" do
    SAGA_FOR_EACH_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "SagaFanoutGrowth" do
        aggregate "GrowthCart" do
          identified_by { cart_key.value }

          value_object "GrowthCartId" do
            attribute :value, String
          end

          attribute :cart_key, GrowthCartId

          command "Checkout" do
            attribute :cart_key, GrowthCartId
            emits "CheckedOut"
          end
        end

        aggregate "GrowthLine" do
          identified_by { id.value }

          value_object "GrowthLineId" do
            attribute :value, String
          end

          attribute :id,      GrowthLineId
          attribute :cart_id, String
          attribute :status,  String, default: "pending"

          command "Add" do
            attribute :id,      GrowthLineId
            attribute :cart_id, String
            emits "Added"
          end

          command "Confirm" do
            reference_to GrowthLine
            then_set :status, to: "confirmed"
          end

          # `for_each` on a SAGA dispatch (unlike a policy's own
          # `for_each`, see #31/#32) enumerates a bare query FQN with no
          # `where:` scoping of its own -- confirmed on real-diff read of
          # the source commit (`DispatchSpec#for_each` is just the query
          # FQN string). Named "Pending", not "ForCart", to spell that
          # honestly: this fans out over every pending line, full stop.
          query "Pending" do
            where status: "pending"
          end
        end

        # GrowthCart's own identity is deliberately named `cart_key`, not
        # the conventional `id` -- `resolve_value` prefers
        # `pm.correlation_head` over a for_each row's own field the
        # moment the two share a Symbol name (found live writing this
        # coverage: with both named `:id`, `with: { id: from_iter(:id) }`
        # silently resolved to the SAGA's own correlation instead of the
        # row's), so this fixture keeps the two symbols distinct on
        # purpose rather than hiding a real, narrow ambiguity in this
        # construct's design.
        process_manager "FanoutSaga" do
          correlates_by :"cart_key.value"
          starts_on "CheckedOut"
          ends_on "AllConfirmed"

          state "checking_out"
          state "fanned_out"

          on "CheckedOut", transition: { "checking_out" => "fanned_out" } do
            dispatch "GrowthLine.Confirm", for_each: { from: "GrowthLine.Pending" }, with: { id: from_iter(:id) }
          end
        end
      end
    BLUEBOOK

    it "fires one dispatch per row the named query returns" do
      runtime = boot(SAGA_FOR_EACH_SOURCE, "SagaFanoutGrowth") do
        ::SagaFanoutGrowth::GrowthCart.persisted_by("Memory")
        ::SagaFanoutGrowth::GrowthLine.persisted_by("Memory")
      end
      runtime.dispatch("SagaFanoutGrowth::GrowthLine.Add", id: { value: "l1" }, cart_id: "c1")
      runtime.dispatch("SagaFanoutGrowth::GrowthLine.Add", id: { value: "l2" }, cart_id: "c1")

      runtime.dispatch("SagaFanoutGrowth::GrowthCart.Checkout", cart_key: { value: "c1" })

      expect(SagaFanoutGrowth::GrowthLine.find("l1").status).to eq("confirmed")
      expect(SagaFanoutGrowth::GrowthLine.find("l2").status).to eq("confirmed")
    end
  end
end
