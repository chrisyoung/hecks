# Hecks::Persistence
#
# Groups all persistence-related mixins: repository CRUD methods,
# collection proxies for list attributes, reference resolution,
# and optional event sourcing via EventRecorder.
#
#   Persistence.bind(agg_class, aggregate, repo)
#
module Hecks
  module Persistence
      autoload :RepositoryMethods, "hecks/services/persistence/repository_methods"
      autoload :CollectionMethods, "hecks/services/persistence/collection_methods"
      autoload :CollectionProxy,   "hecks/services/persistence/collection_proxy"
      autoload :CollectionItem,    "hecks/services/persistence/collection_item"
      autoload :ReferenceMethods,  "hecks/services/persistence/reference_methods"
      autoload :EventRecorder,    "hecks/services/persistence/event_recorder"

      def self.bind(klass, aggregate, repo)
        RepositoryMethods.bind(klass, repo)
        CollectionMethods.bind(klass, aggregate, repo)
        ReferenceMethods.bind(klass, aggregate)
      end

      def self.bind_event_recorder(klass, recorder)
        agg_type = klass.name.split("::").last
        klass.define_singleton_method(:__hecks_event_recorder__) { recorder }
        klass.define_singleton_method(:history) do |id|
          recorder.history(agg_type, id)
        end

        # Wire recorder into command classes
        cmd_mod = begin; klass.const_get(:Commands); rescue NameError; nil; end
        return unless cmd_mod
        cmd_mod.constants.each do |name|
          cmd_class = cmd_mod.const_get(name)
          next unless cmd_class.respond_to?(:event_recorder=)
          cmd_class.event_recorder = recorder
          cmd_class.aggregate_type = agg_type
        end
      end
  end
end
