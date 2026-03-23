# Shared mother domains for break tests. Boot once, reuse.
#
require "tmpdir"

module BreakTestDomains
  @booted = {}

  # Simple domain: one aggregate with String, Integer, Float, JSON
  def self.simple
    @simple ||= Hecks.domain "BrkSimple" do
      aggregate "Item" do
        attribute :name, String
        attribute :count, Integer
        attribute :price, Float
        attribute :data, JSON
        validation :name, presence: true
        command "CreateItem" do
          attribute :name, String
          attribute :count, Integer
          attribute :price, Float
          attribute :data, JSON
        end
        query "ByName" do |name|
          where(name: name)
        end
      end
    end
  end

  # Collection domain: aggregate with list_of value objects + invariant
  def self.collection
    @collection ||= Hecks.domain "BrkColl" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")
        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
          invariant "amount must be positive" do
            amount > 0
          end
        end
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  # Multi-field domain: for query chaining tests
  def self.multi_field
    @multi_field ||= Hecks.domain "BrkMulti" do
      aggregate "Item" do
        attribute :name, String
        attribute :category, String
        attribute :color, String
        attribute :size, String
        attribute :weight, Integer
        command "CreateItem" do
          attribute :name, String
          attribute :category, String
          attribute :color, String
          attribute :size, String
          attribute :weight, Integer
        end
      end
    end
  end

  # Boot a domain (only builds once per domain name)
  def self.boot(domain)
    mod_name = domain.module_name + "Domain"
    unless @booted[mod_name]
      tmpdir = Dir.mktmpdir("hecks_brk")
      gem_path = Hecks.build(domain, output_dir: tmpdir)
      lib_path = File.join(gem_path, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      require domain.gem_name
      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| require f }
      @booted[mod_name] = true
    end
    Hecks::Services::Application.new(domain)
  end
end
