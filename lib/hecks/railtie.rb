# Hecks::Railtie
#
# Rails integration via a simple config block. Handles all the wiring:
# loading the domain gem, generating adapters, booting the Application,
# activating ActiveModel, and hoisting constants.
#
# In config/initializers/hecks.rb:
#
#   Hecks.configure do
#     domain "pizzas_domain"
#     adapter :sql
#   end
#
module Hecks
  class Railtie < ::Rails::Railtie
    initializer "hecks.setup", after: :load_config_initializers do
      if Hecks.configuration
        Hecks.configuration.boot!
      end
    end
  end
end
