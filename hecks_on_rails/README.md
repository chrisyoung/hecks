# HecksOnRails

Full Rails integration for Hecks domains — one gem to get everything.

Bundles `active_hecks` (validations, persistence, Railtie) and `hecks_live` (real-time Turbo Streams) so you don't have to add them separately.

## Usage

```ruby
# Gemfile
gem "hecks_on_rails"
```

That's it. The Railtie auto-detects domain gems in your Gemfile, wires persistence, and sets up ActionCable for live domain events.
