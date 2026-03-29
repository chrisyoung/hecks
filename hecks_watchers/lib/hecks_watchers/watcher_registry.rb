# HecksWatchers::WatcherRegistry
#
# Registry for pre-commit watchers. Each watcher registers itself as either
# :blocking (can fail the commit) or :advisory (warnings only).
#
#   HecksWatchers.register_watcher(:blocking, HecksWatchers::CrossRequire)
#   HecksWatchers.register_watcher(:advisory, HecksWatchers::FileSize)
#   HecksWatchers.blocking_watchers  # => [CrossRequire]
#   HecksWatchers.advisory_watchers  # => [FileSize, ...]
#
module HecksWatchers
  @blocking_watchers = []
  @advisory_watchers = []

  def self.register_watcher(kind, klass)
    case kind
    when :blocking
      @blocking_watchers << klass unless @blocking_watchers.include?(klass)
    when :advisory
      @advisory_watchers << klass unless @advisory_watchers.include?(klass)
    end
  end

  def self.blocking_watchers
    @blocking_watchers.dup
  end

  def self.advisory_watchers
    @advisory_watchers.dup
  end
end
