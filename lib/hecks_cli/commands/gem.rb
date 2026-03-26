# Hecks::CLI::Gem
#
# Gem packaging commands -- build and install the hecks gem from its gemspec.
# Shells out to `gem build` and `gem install` from the project root directory.
#
#   hecks gem build
#   hecks gem install
#
module Hecks
  class CLI < Thor
    class Gem < Thor
      desc "build", "Build the hecks gem from gemspec"
      # Builds the hecks gem by running `gem build hecks.gemspec` in the project root.
      #
      # @return [void]
      def build
        root = gem_root
        return unless root
        Dir.chdir(root) { system("gem build hecks.gemspec") }
      end

      desc "install", "Build and install the hecks gem locally"
      # Builds the hecks gem and installs it locally.
      #
      # Runs `gem build` then `gem install` on the resulting .gem file.
      # Selects the most recently modified .gem file if multiple exist.
      #
      # @return [void]
      def install
        root = gem_root
        return unless root
        Dir.chdir(root) do
          unless system("gem build hecks.gemspec")
            say "Build failed", :red
            return
          end
          gem_file = Dir["hecks-*.gem"].max_by { |f| ::File.mtime(f) }
          unless gem_file
            say "No .gem file found after build", :red
            return
          end
          if system("gem install #{gem_file}")
            say "Installed #{gem_file}", :green
          else
            say "Install failed", :red
          end
        end
      end

      private

      # Locates the gem root directory by checking for hecks.gemspec.
      #
      # @return [String, nil] the project root path, or nil if gemspec not found
      def gem_root
        root = Dir.pwd
        gemspec = ::File.join(root, "hecks.gemspec")
        unless ::File.exist?(gemspec)
          say "hecks.gemspec not found at #{root}", :red
          return nil
        end
        root
      end
    end
  end
end
