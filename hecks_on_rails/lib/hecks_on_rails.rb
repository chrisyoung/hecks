# HecksOnRails
#
# Bundles ActiveHecks + HecksLive for Rails applications.
# Install this one gem to get both request/response and real-time.
#
#   # Gemfile
#   gem "hecks_on_rails"
#
require "hecks"
begin; require "active_hecks"; rescue LoadError; end
begin; require "hecks_live"; rescue LoadError; end

module HecksOnRails
end
