# Hecks::Migrations::DomainSnapshot
#
# Saves and loads domain DSL snapshots for migration diffing. When
# migrations are generated, the current domain is serialized to a
# snapshot file. On the next run, the snapshot is loaded as the "old"
# domain to diff against the current one.
#
#   DomainSnapshot.save(domain, path: ".hecks_domain_snapshot.rb")
#   old_domain = DomainSnapshot.load(path: ".hecks_domain_snapshot.rb")
#
module Hecks
  module Migrations
    class DomainSnapshot
    DEFAULT_PATH = ".hecks_domain_snapshot.rb"

    def self.save(domain, path: DEFAULT_PATH)
      content = DslSerializer.new(domain).serialize
      File.write(path, content)
      path
    end

    def self.load(path: DEFAULT_PATH)
      return nil unless File.exist?(path)

      Kernel.load(path)
      Hecks.last_domain
    end

    def self.exists?(path: DEFAULT_PATH)
      File.exist?(path)
    end
    end
  end
end
