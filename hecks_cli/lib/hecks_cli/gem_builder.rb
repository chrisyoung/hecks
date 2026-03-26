# Hecks::GemBuilder
#
# Builds and installs all Hecks component gems from their subdirectories,
# then the meta-gem. Each component is built from its own directory so that
# Dir globs in gemspecs resolve correctly.
#
#   builder = Hecks::GemBuilder.new("/path/to/hecks")
#   builder.build      # build all .gem files
#   builder.install    # build + install all gems
#
module Hecks
  class GemBuilder
    COMPONENTS = %w[
      hecksties hecks_model hecks_domain hecks_runtime
      hecks_session hecks_cli hecks_persist hecks_watchers
    ].freeze

    attr_reader :root

    # @param root [String] path to the hecks project root (must contain hecks.gemspec)
    # @param output [#call] callback for status messages, receives (message, color)
    def initialize(root, output: method(:default_output))
      @root = root
      @output = output
    end

    # Builds all component gems and the meta-gem.
    #
    # @return [Boolean] true if all builds succeeded
    def build
      COMPONENTS.each do |name|
        next if skip_missing?(name)
        return false unless build_component(name)
      end
      @output.call("Building hecks meta-gem...", :green)
      Dir.chdir(root) { system("gem build hecks.gemspec") }
    end

    # Builds and installs all component gems, then the meta-gem.
    #
    # @return [Boolean] true if all builds and installs succeeded
    def install
      COMPONENTS.each do |name|
        next if skip_missing?(name)
        return false unless install_component(name)
      end
      @output.call("Building hecks meta-gem...", :green)
      Dir.chdir(root) do
        return build_failed("hecks") unless system("gem build hecks.gemspec")
        gem_file = newest_gem("hecks")
        return install_failed("hecks") unless gem_file && system("gem install #{gem_file}")
        File.delete(gem_file)
        @output.call("Installed #{gem_file}", :green)
      end
      true
    end

    private

    def component_dir(name)
      File.join(root, name)
    end

    def gemspec_path(name)
      File.join(component_dir(name), "#{name}.gemspec")
    end

    def skip_missing?(name)
      unless File.exist?(gemspec_path(name))
        @output.call("Skipping #{name} (no gemspec)", :yellow)
        true
      end
    end

    def build_component(name)
      @output.call("Building #{name}...", :green)
      Dir.chdir(component_dir(name)) do
        return build_failed(name) unless system("gem build #{name}.gemspec")
        Dir["#{name}-*.gem"].each { |f| File.delete(f) }
      end
      true
    end

    def install_component(name)
      @output.call("Building #{name}...", :green)
      Dir.chdir(component_dir(name)) do
        return build_failed(name) unless system("gem build #{name}.gemspec")
        gem_file = newest_gem(name)
        return install_failed(name) unless gem_file && system("gem install #{gem_file}")
        File.delete(gem_file)
        @output.call("Installed #{gem_file}", :green)
      end
      true
    end

    def newest_gem(name)
      Dir["#{name}-*.gem"].max_by { |f| File.mtime(f) }
    end

    def build_failed(name)
      @output.call("Build failed for #{name}", :red)
      false
    end

    def install_failed(name)
      @output.call("Install failed for #{name}", :red)
      false
    end

    def default_output(message, _color = nil)
      puts message
    end
  end
end
