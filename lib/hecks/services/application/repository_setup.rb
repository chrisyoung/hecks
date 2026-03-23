# Hecks::Services::Application::RepositorySetup
#
# Mixin that creates a memory-adapter repository for each aggregate,
# unless an explicit adapter override was supplied in the Application
# config block.
#
#   class Application
#     include RepositorySetup
#   end
#
module Hecks
  module Services
    class Application
      module RepositorySetup
        private

        def setup_repositories
          @domain.aggregates.each do |agg|
            if @adapter_overrides.key?(agg.name)
              @repositories[agg.name] = @adapter_overrides[agg.name]
            else
              adapter_class = @mod::Adapters.const_get("#{agg.name}MemoryRepository")
              @repositories[agg.name] = adapter_class.new
            end
          end
        end
      end
    end
  end
end
