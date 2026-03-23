# Hecks::TestHelper
#
# Automatically resets Hecks state between tests. Clears all memory
# adapter stores and event history so each test starts clean.
#
# For RSpec, just require it — it hooks in automatically:
#
#   # spec_helper.rb or rails_helper.rb
#   require "hecks/test_helper"
#
# For Minitest:
#
#   class ActiveSupport::TestCase
#     include Hecks::TestHelper
#   end
#
module Hecks
  module TestHelper
    def self.reset!
      return unless defined?(APP) && APP.is_a?(Hecks::Services::Application)

      # Clear all memory adapter stores
      APP.domain.aggregates.each do |agg|
        repo = APP[agg.name]
        repo.clear if repo&.respond_to?(:clear)
      end

      # Clear event history
      APP.event_bus.clear
    end
  end
end

# Auto-hook into RSpec if it's loaded
if defined?(RSpec)
  RSpec.configure do |config|
    config.after(:each) do
      Hecks::TestHelper.reset!
    end
  end
end
