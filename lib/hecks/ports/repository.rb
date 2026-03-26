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
      autoload :RepositoryMethods, "hecks/ports/repository/repository_methods"
      autoload :CollectionMethods, "hecks/ports/repository/collection_methods"
      autoload :CollectionProxy,   "hecks/ports/repository/collection_proxy"
      autoload :CollectionItem,    "hecks/ports/repository/collection_item"
      autoload :ReferenceMethods,  "hecks/ports/repository/reference_methods"
      autoload :EventRecorder,    "hecks/ports/repository/event_recorder"

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
