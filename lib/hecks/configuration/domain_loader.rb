# Hecks::Configuration::DomainLoader
#
# Loads domain definitions from installed gems or local paths.
# Gem loading requires the gem and reads hecks_domain.rb from it.
# Path loading builds the domain gem on the fly before loading.
#
#   domain "pizzas_domain"                  # from gem
#   domain "pizzas_domain", path: "domain/" # local, builds on boot
#
module Hecks
  class Configuration
    module DomainLoader
      private

      def load_domain(d)
        d[:path] ? load_from_path(d) : load_from_gem(d)
      end

      def load_from_path(d)
        base = if defined?(::Rails)
                 ::Rails.root.join(d[:path]).to_s
               else
                 File.expand_path(d[:path])
               end

        domain_file = File.join(base, "hecks_domain.rb")
        domain_obj = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)
        domain_obj.source_path = domain_file

        gem_path = Hecks.build(domain_obj, output_dir: base)
        lib_path = File.join(gem_path, "lib")
        $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
        require d[:gem_name]
        Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
        domain_module = Object.const_get(domain_obj.module_name + "Domain")
        [domain_obj, domain_module]
      end

      def load_from_gem(d)
        gem d[:gem_name], d[:version] if d[:version]
        require d[:gem_name]

        gem_path = if Gem.loaded_specs[d[:gem_name]]
                     Gem.loaded_specs[d[:gem_name]].full_gem_path
                   elsif defined?(::Rails)
                     ::Rails.root.join(d[:gem_name]).to_s
                   else
                     File.join(Dir.pwd, d[:gem_name])
                   end

        domain_file = File.join(gem_path, "hecks_domain.rb")
        domain_obj = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)
        domain_obj.source_path = domain_file
        domain_module = Object.const_get(domain_obj.module_name + "Domain")
        [domain_obj, domain_module]
      end
    end
  end
end
