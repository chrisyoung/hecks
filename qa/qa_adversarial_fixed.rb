#!/usr/bin/env ruby
# QA Adversarial Testing Script - FIXED
# Intentionally tries to break the system through edge cases and rule violations
# Run with: rspec qa_adversarial_fixed.rb --format progress

require "spec_helper"

RSpec.describe "QA Adversarial Tests - Breaking the System" do
  let(:pizzas_runtime) { boot_in_memory_for(:pizzas) }
  let(:banking_runtime) { boot_in_memory_for(:banking) }

  def boot_in_memory_for(domain)
    case domain
    when :pizzas
      runtime = boot_in_memory
      # Load pizzas domain
      Hecksagain.with_registry(runtime.registry) do
        Kernel.load(File.join(InMemoryDomain::ROOT, "examples/pizzas/bluebook/pizzas.bluebook"))
      end
      runtime
    when :banking
      runtime = boot_in_memory
      # Load banking domain
      Hecksagain.with_registry(runtime.registry) do
        Kernel.load(File.join(InMemoryDomain::ROOT, "examples/banking/bluebook/banking.bluebook"))
      end
      runtime
    end
  end

  describe "Pizzas Domain - Adversarial Attacks" do

    describe "numeric boundary conditions" do
      it "rejects zero-price pizzas" do
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                 name: { value: "Free" },
                                 pizza: { price_cents: { cents: 0 }, size: { value: "large" } })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end

      it "rejects negative pizza prices" do
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                 name: { value: "Bad" },
                                 pizza: { price_cents: { cents: -100 }, size: { value: "large" } })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end

      it "accepts extremely large pizza prices without overflow" do
        result = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                        name: { value: "Expensive" },
                                        pizza: { price_cents: { cents: 999_999_999_999 }, size: { value: "large" } })

        expect(result.state[:pizza][:price_cents][:cents]).to be > 0
      end

      it "rejects negative topping amounts" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        expect {
          pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                 name: pizza.id,
                                 topping: { value: "Basil" },
                                 amount: { value: -5 })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation, /positive/)
      end

      it "rejects zero topping amounts" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        expect {
          pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                 name: pizza.id,
                                 topping: { value: "Basil" },
                                 amount: { value: 0 })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end
    end

    describe "empty string validation" do
      it "rejects empty pizza names" do
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                 name: { value: "" },
                                 pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end

      it "rejects empty customer names at purchase" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                               name: pizza.id,
                               topping: { value: "Basil" },
                               amount: { value: 3 })

        expect {
          pizzas_runtime.dispatch("Pizzas::Order.Purchase",
                                 name: pizza.id,
                                 customer_name: { value: "" },
                                 amount: { cents: 1200 })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end

      it "rejects empty topping names" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        expect {
          pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                 name: pizza.id,
                                 topping: { value: "" },
                                 amount: { value: 3 })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end
    end

    describe "state violation attacks" do
      it "refuses to add toppings after purchase" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                               name: pizza.id,
                               topping: { value: "Basil" },
                               amount: { value: 3 })

        pizzas_runtime.dispatch("Pizzas::Order.Purchase",
                               name: pizza.id,
                               customer_name: { value: "Chris" },
                               amount: { cents: 1200 })

        # Try to add topping to sold pizza
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                 name: pizza.id,
                                 topping: { value: "Olive" },
                                 amount: { value: 2 })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet, /cannot be changed/)
      end

      it "refuses purchase before minimum toppings" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        # Try to purchase without toppings
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.Purchase",
                                 name: pizza.id,
                                 customer_name: { value: "Chris" },
                                 amount: { cents: 1200 })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet, /at least one topping/)
      end

      it "refuses purchase with insufficient payment" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                               name: pizza.id,
                               topping: { value: "Basil" },
                               amount: { value: 3 })

        expect {
          pizzas_runtime.dispatch("Pizzas::Order.Purchase",
                                 name: pizza.id,
                                 customer_name: { value: "Chris" },
                                 amount: { cents: 500 }) # Less than pizza price
        }.to raise_error(Hecksagain::Runtime::GivenNotMet, /enough/)
      end

      it "refuses second purchase on same pizza" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                               name: pizza.id,
                               topping: { value: "Basil" },
                               amount: { value: 3 })

        pizzas_runtime.dispatch("Pizzas::Order.Purchase",
                               name: pizza.id,
                               customer_name: { value: "Chris" },
                               amount: { cents: 1200 })

        # Try to purchase again
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.Purchase",
                                 name: pizza.id,
                                 customer_name: { value: "Someone" },
                                 amount: { cents: 1200 })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet, /still be available/)
      end
    end

    describe "identity attacks" do
      it "rejects operations on non-existent pizzas" do
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                 name: "nonexistent-id",
                                 topping: { value: "Basil" },
                                 amount: { value: 3 })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end

      it "handles SQL injection-like ID attempts safely" do
        expect {
          pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                 name: "'; DROP TABLE orders; --",
                                 topping: { value: "Basil" },
                                 amount: { value: 3 })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end
    end

    describe "rapid mutation stress test" do
      it "handles many topping additions without data loss" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        toppings = ["Basil", "Olive", "Mushroom", "Onion", "Pepper", "Cheese", "Tomato", "Garlic"]

        toppings.each_with_index do |topping, idx|
          result = pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                          name: pizza.id,
                                          topping: { value: topping },
                                          amount: { value: idx + 1 })

          expect(result.state[:toppings].length).to eq(idx + 1), "Should have #{idx + 1} toppings"
        end

        # Final verification
        final = pizzas_runtime.fetch("Pizzas::Order", pizza.id)
        expect(final.toppings.length).to eq(toppings.length)
      end
    end

    describe "special character handling" do
      it "safely handles unicode characters in pizza names" do
        result = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                        name: { value: "🍕 Unicode Pizza" },
                                        pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        expect(result.state[:name][:value]).to include("🍕")
      end

      it "safely handles SQL-like special characters" do
        result = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                        name: { value: "O'Reilly's & Co.; DROP TABLE--" },
                                        pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        expect(result.state[:name][:value]).to include("O'Reilly's")
      end

      it "handles very long pizza names without truncation issues" do
        long_name = "A" * 10000
        result = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                        name: { value: long_name },
                                        pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        expect(result.state[:name][:value].length).to eq(long_name.length)
      end
    end

    describe "topping limit enforcement" do
      it "documents topping limit behavior under stress" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        # Try to add many toppings
        results = (1..15).map do |i|
          begin
            pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                   name: pizza.id,
                                   topping: { value: "Topping#{i}" },
                                   amount: { value: 1 })
          rescue => e
            e
          end
        end

        # Check if limit was enforced
        if results.any? { |r| r.is_a?(Exception) }
          puts "NOTE: Topping limit enforced - accepts up to #{results.index { |r| r.is_a?(Exception) } || 15} toppings"
        else
          final = pizzas_runtime.fetch("Pizzas::Order", pizza.id)
          puts "NOTE: No topping limit enforced (#{final.toppings.length} toppings allowed)"
        end

        expect(results.first).not_to be_a(Exception), "First few toppings should be accepted"
      end
    end

    describe "event stream integrity" do
      it "maintains correct event ordering under rapid operations" do
        pizza = pizzas_runtime.dispatch("Pizzas::Order.CreatePizza",
                                       name: { value: "Test" },
                                       pizza: { price_cents: { cents: 1200 }, size: { value: "large" } })

        3.times do |i|
          pizzas_runtime.dispatch("Pizzas::Order.AddTopping",
                                 name: pizza.id,
                                 topping: { value: "Topping#{i}" },
                                 amount: { value: 1 })
        end

        events = pizzas_runtime.events.map(&:name)

        expect(events[0]).to eq("PizzaCreated"), "First event should be PizzaCreated"
        expect(events[1..3].all? { |e| e == "ToppingAdded" }).to be true, "Following events should all be ToppingAdded"
      end
    end
  end

  describe "Banking Domain - Adversarial Attacks" do
    before do
      banking_runtime.dispatch("Banking::Account.Open", number: { value: "acct-1" })
      banking_runtime.dispatch("Banking::Account.Open", number: { value: "acct-2" })
    end

    describe "transfer validation" do
      it "rejects negative transfer amounts" do
        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "acct-1",
                                  destination: "acct-2",
                                  amount: { cents: -1000 },
                                  narrative: { text: "Bad" },
                                  reference: { value: "xfer-1" })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end

      it "rejects zero-amount transfers" do
        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "acct-1",
                                  destination: "acct-2",
                                  amount: { cents: 0 },
                                  narrative: { text: "Nothing" },
                                  reference: { value: "xfer-0" })
        }.to raise_error(Hecksagain::Runtime::InvariantViolation)
      end
    end

    describe "account state violations" do
      it "rejects transfer to same account" do
        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "acct-1",
                                  destination: "acct-1",
                                  amount: { cents: 1000 },
                                  narrative: { text: "Self" },
                                  reference: { value: "xfer-self" })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end

      it "rejects transfer from frozen account" do
        banking_runtime.dispatch("Banking::Account.Freeze", number: { value: "acct-1" })

        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "acct-1",
                                  destination: "acct-2",
                                  amount: { cents: 1000 },
                                  narrative: { text: "Frozen" },
                                  reference: { value: "xfer-frozen" })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end

      it "rejects transfer to frozen account" do
        banking_runtime.dispatch("Banking::Account.Freeze", number: { value: "acct-2" })

        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "acct-1",
                                  destination: "acct-2",
                                  amount: { cents: 1000 },
                                  narrative: { text: "ToFrozen" },
                                  reference: { value: "xfer-to-frozen" })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end
    end

    describe "duplicate reference handling" do
      it "rejects duplicate transfer references" do
        banking_runtime.dispatch("Banking::Transfer.Request",
                                source: "acct-1",
                                destination: "acct-2",
                                amount: { cents: 1000 },
                                narrative: { text: "First" },
                                reference: { value: "xfer-dup" })

        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "acct-1",
                                  destination: "acct-2",
                                  amount: { cents: 500 },
                                  narrative: { text: "Duplicate" },
                                  reference: { value: "xfer-dup" })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end
    end

    describe "nonexistent account attacks" do
      it "rejects transfer from nonexistent account" do
        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "nonexistent",
                                  destination: "acct-2",
                                  amount: { cents: 1000 },
                                  narrative: { text: "Bad source" },
                                  reference: { value: "xfer-bad-src" })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end

      it "rejects transfer to nonexistent account" do
        expect {
          banking_runtime.dispatch("Banking::Transfer.Request",
                                  source: "acct-1",
                                  destination: "nonexistent",
                                  amount: { cents: 1000 },
                                  narrative: { text: "Bad dest" },
                                  reference: { value: "xfer-bad-dst" })
        }.to raise_error(Hecksagain::Runtime::GivenNotMet)
      end
    end
  end
end
