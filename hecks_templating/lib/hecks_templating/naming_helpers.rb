# = Hecks::NamingHelpers
#
# Universal mixin that delegates to Hecks::Templating::Names.
# Include in any class or module — methods are available as both
# instance methods AND class/module methods. Works everywhere.
#
#   include Hecks::NamingHelpers
#   domain_module_name("Pizzas")     # => "PizzasDomain"
#   domain_aggregate_slug("Pizza")   # => "pizzas"
#   domain_command_method("CreatePizza", "Pizza") # => :create
#
module Hecks
  module NamingHelpers
    def self.included(base)
      methods = Hecks::Templating::Names.singleton_class.public_instance_methods(false)
      # Instance methods (for use inside class/module instance methods)
      methods.each do |m|
        base.define_method(m) { |*args, **kwargs| Hecks::Templating::Names.send(m, *args, **kwargs) }
      end
      # Class/module methods (for use in self.method, module_function, etc.)
      methods.each do |m|
        base.define_singleton_method(m) { |*args, **kwargs| Hecks::Templating::Names.send(m, *args, **kwargs) }
      end
    end

    def self.extended(base)
      Hecks::Templating::Names.singleton_class.public_instance_methods(false).each do |m|
        base.define_singleton_method(m) { |*args, **kwargs| Hecks::Templating::Names.send(m, *args, **kwargs) }
      end
    end
  end
end
