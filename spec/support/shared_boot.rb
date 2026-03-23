# Shared domain boot — build once, reuse everywhere.
# Include in spec_helper to make BootedDomains available to all specs.
#
require "tmpdir"

module BootedDomains
  @cache = {}

  def self.pizzas
    @pizzas_domain ||= Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :description, String
        attribute :price, Float
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer

          invariant "amount must be positive" do
            amount > 0
          end
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
          attribute :description, String
          attribute :price, Float
        end

        command "AddTopping" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :topping, String
        end

        query "ByDescription" do |desc|
          where(description: desc)
        end

        query "Classics" do
          where(style: "Classic")
        end

        query "ByStyle" do |style|
          where(style: style)
        end

        scope :classics_scope, style: "Classic"
        scope :by_style_scope, ->(s) { { style: s } }
      end

      aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer
        attribute :status, String

        validation :quantity, presence: true

        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end

        command "CancelOrder" do
          attribute :pizza_id, reference_to("Pizza")
        end

        command "ReserveStock" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end

        query "Pending" do
          where(status: "pending")
        end

        policy "ReserveIngredients" do
          on "PlacedOrder"
          trigger "ReserveStock"
        end
      end
    end
  end

  def self.boot(domain)
    key = domain.object_id
    return @cache[key] if @cache[key]

    mod_name = domain.module_name + "Domain"
    unless Object.const_defined?(mod_name)
      tmpdir = Dir.mktmpdir("hecks_shared_boot")
      gem_path = Hecks.build(domain, output_dir: tmpdir)
      lib_path = File.join(gem_path, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      require domain.gem_name
      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| require f }
    end

    @cache[key] = true
    Hecks::Services::Application.new(domain)
  end
end
