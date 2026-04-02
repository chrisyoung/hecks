require "spec_helper"
require "hecks/extensions/failover"

RSpec.describe "hecks_failover extension" do
  let(:domain) do
    Hecks.domain "FailoverTest" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  after do
    Hecks.actor = nil
    Hecks.tenant = nil
  end

  describe HecksFailover::FailoverProxy do
    it "delegates to primary in normal mode" do
      app = Hecks.load(domain)
      repo = app["Widget"]
      proxy = HecksFailover::FailoverProxy.new(repo)

      FailoverTestDomain::Widget.create(name: "Bolt")
      saved = repo.all.first

      expect(proxy.find(saved.id)).to eq(saved)
      expect(proxy.all.size).to eq(1)
      expect(proxy.count).to eq(1)
      expect(proxy.mode).to eq(:primary)
      expect(proxy.failed_over?).to be false
    end

    it "fails over to fallback when primary raises" do
      failing_repo = Object.new
      def failing_repo.find(_id); raise "connection lost"; end
      def failing_repo.save(_a); raise "connection lost"; end
      def failing_repo.delete(_id); raise "connection lost"; end
      def failing_repo.all; raise "connection lost"; end
      def failing_repo.count; raise "connection lost"; end
      def failing_repo.query(**_kw); raise "connection lost"; end
      def failing_repo.clear; raise "connection lost"; end

      proxy = HecksFailover::FailoverProxy.new(failing_repo)

      expect(proxy.all).to eq([])
      expect(proxy.failed_over?).to be true
      expect(proxy.mode).to eq(:failover)
    end

    it "logs writes during failover for later replay" do
      failing_repo = Object.new
      def failing_repo.all; raise "down"; end
      def failing_repo.count; raise "down"; end
      def failing_repo.save(_a); raise "down"; end
      def failing_repo.find(_id); raise "down"; end
      def failing_repo.delete(_id); raise "down"; end
      def failing_repo.query(**_kw); raise "down"; end
      def failing_repo.clear; raise "down"; end

      proxy = HecksFailover::FailoverProxy.new(failing_repo)
      proxy.all # trigger failover

      widget = Struct.new(:id, :name).new("w1", "Gear")
      proxy.save(widget)

      expect(proxy.write_log.size).to eq(1)
      expect(proxy.write_log.first[:op]).to eq(:save)
      expect(proxy.find("w1").name).to eq("Gear")
    end

    it "recovers when primary comes back" do
      store = {}
      healthy_repo = Object.new
      healthy_repo.define_singleton_method(:all) { store.values }
      healthy_repo.define_singleton_method(:count) { store.size }
      healthy_repo.define_singleton_method(:save) { |a| store[a.id] = a }
      healthy_repo.define_singleton_method(:find) { |id| store[id] }
      healthy_repo.define_singleton_method(:delete) { |id| store.delete(id) }

      # Start with a broken wrapper to simulate failure
      broken = true
      wrapper = Object.new
      wrapper.define_singleton_method(:all) { broken ? (raise "down") : healthy_repo.all }
      wrapper.define_singleton_method(:count) { broken ? (raise "down") : healthy_repo.count }
      wrapper.define_singleton_method(:save) { |a| broken ? (raise "down") : healthy_repo.save(a) }
      wrapper.define_singleton_method(:find) { |id| broken ? (raise "down") : healthy_repo.find(id) }
      wrapper.define_singleton_method(:delete) { |id| broken ? (raise "down") : healthy_repo.delete(id) }

      proxy = HecksFailover::FailoverProxy.new(wrapper)
      proxy.all # trigger failover

      widget = Struct.new(:id, :name).new("w1", "Bolt")
      proxy.save(widget)

      expect(proxy.failed_over?).to be true

      # "Fix" the primary
      broken = false
      expect(proxy.recover!).to be true
      expect(proxy.failed_over?).to be false
      expect(proxy.write_log).to be_empty
      expect(store["w1"].name).to eq("Bolt")
    end
  end

  describe HecksFailover::RecoveryMonitor do
    it "recovers all failed-over proxies" do
      store = {}
      repo = Object.new
      repo.define_singleton_method(:all) { store.values }
      repo.define_singleton_method(:count) { store.size }
      repo.define_singleton_method(:save) { |a| store[a.id] = a }

      broken = true
      wrapper = Object.new
      wrapper.define_singleton_method(:all) { broken ? (raise "down") : repo.all }
      wrapper.define_singleton_method(:count) { broken ? (raise "down") : repo.count }
      wrapper.define_singleton_method(:save) { |a| broken ? (raise "down") : repo.save(a) }

      proxy = HecksFailover::FailoverProxy.new(wrapper)
      proxy.all # trigger failover

      monitor = HecksFailover::RecoveryMonitor.new([proxy])

      # Still broken
      result = monitor.recover!
      expect(result[:still_failed]).to eq(1)

      # Fix it
      broken = false
      result = monitor.recover!
      expect(result[:recovered]).to eq(1)
      expect(proxy.failed_over?).to be false
    end
  end

  describe "extension wiring" do
    it "provides Hecks.failover_status and Hecks.failover_recover!" do
      Hecks.extension_registry.delete(:failover)
      load File.expand_path("../../../lib/hecks/extensions/failover.rb", __FILE__)

      app = Hecks.load(domain)
      Hecks.extension_registry[:failover]&.call(
        Object.const_get("FailoverTestDomain"), domain, app
      )

      status = Hecks.failover_status
      expect(status[:mode]).to eq(:primary)
      expect(status[:write_log_size]).to eq(0)

      result = Hecks.failover_recover!
      expect(result[:recovered]).to eq(0)
      expect(result[:still_failed]).to eq(0)
    end
  end
end
