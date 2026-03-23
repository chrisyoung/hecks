# Hecks::Services::Persistence
#
# Groups all persistence-related mixins: repository CRUD methods,
# collection proxies for list attributes, and reference resolution.
#
#   Persistence.bind(agg_class, aggregate, repo)
#
module Hecks
  module Services
    module Persistence
      autoload :RepositoryMethods, "hecks/services/persistence/repository_methods"
      autoload :CollectionMethods, "hecks/services/persistence/collection_methods"
      autoload :CollectionProxy,   "hecks/services/persistence/collection_proxy"
      autoload :CollectionItem,    "hecks/services/persistence/collection_proxy"
      autoload :ReferenceMethods,  "hecks/services/persistence/reference_methods"

      def self.bind(klass, aggregate, repo)
        RepositoryMethods.bind(klass, repo)
        CollectionMethods.bind(klass, aggregate, repo)
        ReferenceMethods.bind(klass, aggregate)
      end
    end
  end
end
