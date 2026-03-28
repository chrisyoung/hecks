# Live Events

Real-time domain event streaming via Turbo Streams + ActionCable

## Install

```ruby
# Gemfile
gem "hecks_live"
```

Add the gem and it auto-wires on boot. No configuration needed.

## Usage

```ruby
# Rails view:
<%= turbo_stream_from "hecks_live_events" %>
<div id="event-feed"></div>
# Events auto-prepend. No custom JS.
```

## Details

Real-time domain event streaming. In Rails, events broadcast via
Turbo Streams + ActionCable automatically. Outside Rails, events
print to stdout.

Usage (Rails view):
  <%= turbo_stream_from "hecks_live_events" %>
  <div id="event-feed"></div>

That's it. HecksLive handles the rest.
