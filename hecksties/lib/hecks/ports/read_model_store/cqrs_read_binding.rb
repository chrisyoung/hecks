# Hecks::CqrsReadBinding
#
# Rebinds class-level read methods (find, all, count, first, last) on an
# aggregate class to use a read-side repository instead of the write repo.
# Also rebinds where/find_by/order/limit/offset via AdHocQueries. Called
# by PortSetup when CQRS is active for an aggregate.
#
#   CqrsReadBinding.bind(Pizza, read_repo)
#   Pizza.all    # => reads from read_repo
#   Pizza.find(1) # => reads from read_repo
#   # But pizza.save still writes to the write repo
#
module Hecks
  module CqrsReadBinding
    # Rebinds read methods on the aggregate class to use the read repository.
    #
    # @param klass [Class] the aggregate class
    # @param read_repo [Object] the read-side repository
    # @return [void]
    def self.bind(klass, read_repo)
      klass.define_singleton_method(:find) { |id| read_repo.find(id) }
      klass.define_singleton_method(:all) { read_repo.all }
      klass.define_singleton_method(:count) { read_repo.count }
      klass.define_singleton_method(:first) { all.first }
      klass.define_singleton_method(:last) { all.last }

      # Also set the repo reference used by ScopeMethods
      klass.instance_variable_set(:@__hecks_read_repo__, read_repo)

      Querying::AdHocQueries.bind(klass, read_repo)
    end
  end
end
