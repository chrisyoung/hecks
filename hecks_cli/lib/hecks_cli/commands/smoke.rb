# Hecks::CLI#smoke
#
# Runs all smoke tests to verify examples boot correctly.
#
#   hecks smoke
#
module Hecks
  class CLI < Thor
    desc "smoke", "Run smoke tests on all examples"
    def smoke
      require "open3"
      output, status = Open3.capture2e("bundle", "exec", "rspec", "--pattern", "hecks_smoke/spec/**/*_spec.rb", "--format", "documentation")
      puts output
      exit(status.exitstatus)
    end
  end
end
