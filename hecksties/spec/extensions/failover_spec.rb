require "spec_helper"
require "hecks/extensions/failover"

RSpec.describe "Failover extension" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  describe Hecks::FailoverProxy do
    let(:failing_repo) do
      repo = Object.new
      def repo.save(_); raise "connection lost"; end
      def repo.find(_); raise "connection lost"; end
      def repo.all; raise "connection lost"; end
      def repo.count; raise "connection lost"; end
      def repo.delete(_); raise "connection lost"; end
      def repo.clear; raise "connection lost"; end
      def repo.query(**_); raise "connection lost"; end
      repo
    end

    it "falls back on write failure and queues writes" do
      proxy = Hecks::FailoverProxy.new(primary: failing_repo)
      app = Hecks.load(domain)

      entity = PizzasDomain::Pizza.create(name: "Test")
      result = proxy.save(entity)

      expect(result).to eq(entity)
      expect(proxy.degraded?).to be true
      expect(proxy.queue_size).to eq(1)
    end

    it "serves reads from fallback when degraded" do
      proxy = Hecks::FailoverProxy.new(primary: failing_repo)
      app = Hecks.load(domain)

      entity = PizzasDomain::Pizza.create(name: "Fallback")
      proxy.save(entity)

      found = proxy.find(entity.id)
      expect(found).to eq(entity)
    end

    it "recovers by replaying the write log" do
      real_store = {}
      healthy_repo = Object.new
      healthy_repo.define_singleton_method(:save) { |e| real_store[e.id] = e }
      healthy_repo.define_singleton_method(:find) { |id| real_store[id] }
      healthy_repo.define_singleton_method(:all) { real_store.values }

      proxy = Hecks::FailoverProxy.new(primary: failing_repo)
      app = Hecks.load(domain)

      entity = PizzasDomain::Pizza.create(name: "Queued")
      proxy.save(entity)
      expect(proxy.degraded?).to be true

      # Swap to healthy and recover
      proxy.instance_variable_set(:@primary, healthy_repo)
      replayed = proxy.recover!

      expect(replayed).to eq(1)
      expect(proxy.degraded?).to be false
      expect(proxy.queue_size).to eq(0)
      expect(healthy_repo.find(entity.id)).to eq(entity)
    end
  end

  describe "extension wiring" do
    it "reports healthy status with working adapter" do
      app = Hecks.load(domain)
      app.extend(:failover)

      expect(Hecks.failover_status).to eq(:healthy)
      expect(Hecks.failover_queue_size).to eq(0)
    end
  end
end
