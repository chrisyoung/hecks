module Hecks
  module ValidationRules
    module WorldGoals

      # Hecks::ValidationRules::WorldGoals::Equity
      #
      # When the :equity goal is declared, this rule flags aggregates that have
      # pricing or rate attributes (names containing "price", "cost", "fee", "rate")
      # but lack documentation or specification details about how pricing is
      # calculated, applied, or varied.
      #
      # This is an advisory warning, not an error. It encourages transparent and
      # fair pricing practices by ensuring pricing decisions are explicit and
      # reviewable.
      #
      #   world_goals :equity
      #
      #   aggregate "Service" do
      #     attribute :price, Float          # <-- warns: pricing attribute without spec
      #     attribute :rate, Float
      #     invariant "Pricing must be cost-plus",
      #       message: "price >= cost + minimum_margin"  # <-- better: documented
      #   end
      #
      class Equity < BaseRule
        PRICING_PATTERNS = %w[
          price cost fee rate charge amount margin discount markup
        ].freeze

        def errors
          []
        end

        def warnings
          return [] unless @domain.world_goals.include?(:equity)

          issues = []
          @domain.aggregates.each do |agg|
            pricing_attrs = agg.attributes.select { |attr| pricing_attribute?(attr.name.to_s) }
            next if pricing_attrs.empty?

            # Check if aggregate has invariants or policies explaining pricing
            has_pricing_doc = agg.invariants.any? { |inv| inv_mentions_pricing?(inv) } ||
                              agg.policies.any? { |pol| pol_mentions_pricing?(pol) }

            unless has_pricing_doc
              pricing_names = pricing_attrs.map { |a| a.name }.join(", ")
              issues << "Equity: #{agg.name} has pricing attributes (#{pricing_names}) " \
                        "but no documented invariant or policy explaining how pricing works. " \
                        "Add invariants or policies to make pricing logic explicit and reviewable."
            end
          end
          issues
        end

        private

        def pricing_attribute?(name)
          PRICING_PATTERNS.any? { |pat| name.downcase.include?(pat) }
        end

        def inv_mentions_pricing?(inv)
          inv.message.to_s.downcase.include?("price") ||
            inv.message.to_s.downcase.include?("cost") ||
            inv.message.to_s.downcase.include?("rate")
        end

        def pol_mentions_pricing?(pol)
          pol.name.to_s.downcase.include?("price") ||
            pol.name.to_s.downcase.include?("cost") ||
            pol.name.to_s.downcase.include?("rate")
        end
      end
      Hecks.register_validation_rule(Equity)
    end
  end
end
