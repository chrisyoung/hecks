# Hecks::HTTP::LiveEventsJs
#
# Returns the inline JavaScript for the HecksLiveEvents class and its
# companion CSS. Used by layout templates to embed live event streaming
# support without external asset files.
#
# The JavaScript uses EventSource (SSE) with automatic reconnect. Events
# are displayed in a fixed-position overlay that auto-scrolls and caps
# at a configurable maxEvents limit.
#
# Usage:
#   Hecks::HTTP::LiveEventsJs.script_tag  # => "<script>...</script>"
#   Hecks::HTTP::LiveEventsJs.style_tag   # => "<style>...</style>"

module Hecks
  module HTTP
    module LiveEventsJs
      # Returns a <style> tag with CSS for the live events indicator and panel.
      #
      # @return [String] HTML style tag
      def self.style_tag
        <<~HTML
          <style>
            .hecks-live { position: fixed; bottom: 1rem; right: 1rem; z-index: 9999; font-family: ui-monospace, monospace; font-size: 0.8rem; }
            .hecks-live-toggle { background: #1a1a2e; color: #4ade80; border: none; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; display: flex; align-items: center; gap: 0.4rem; }
            .hecks-live-toggle .dot { width: 8px; height: 8px; border-radius: 50%; background: #4ade80; }
            .hecks-live-toggle.disconnected .dot { background: #f87171; }
            .hecks-live-toggle.disconnected { color: #f87171; }
            .hecks-live-panel { display: none; background: #1a1a2e; color: #e0e0e0; border-radius: 8px; padding: 0.75rem; margin-bottom: 0.5rem; width: 360px; max-height: 300px; overflow-y: auto; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
            .hecks-live-panel.open { display: block; }
            .hecks-live-panel .event-line { padding: 0.25rem 0; border-bottom: 1px solid #2a2a4e; }
            .hecks-live-panel .event-type { color: #4ade80; font-weight: 600; }
            .hecks-live-panel .event-time { color: #888; margin-left: 0.5rem; }
            .hecks-live-panel .empty { color: #666; font-style: italic; }
          </style>
        HTML
      end

      # Returns a <script> tag with the HecksLiveEvents class and auto-init.
      #
      # @return [String] HTML script tag
      def self.script_tag
        <<~HTML
          <script>
            (function() {
              function HecksLiveEvents(opts) {
                opts = opts || {};
                this.url = opts.url || '/_live';
                this.maxEvents = opts.maxEvents || 50;
                this.events = [];
                this.source = null;
                this.listeners = [];
                this.connected = false;
                this.connect();
              }

              HecksLiveEvents.prototype.connect = function() {
                var self = this;
                this.source = new EventSource(this.url);
                this.source.onopen = function() {
                  self.connected = true;
                  self.updateIndicator();
                };
                this.source.onmessage = function(e) {
                  var evt = JSON.parse(e.data);
                  self.events.push(evt);
                  if (self.events.length > self.maxEvents) self.events.shift();
                  self.listeners.forEach(function(fn) { fn(evt); });
                  self.renderPanel();
                };
                this.source.onerror = function() {
                  self.connected = false;
                  self.updateIndicator();
                };
              };

              HecksLiveEvents.prototype.disconnect = function() {
                if (this.source) { this.source.close(); this.source = null; }
                this.connected = false;
                this.updateIndicator();
              };

              HecksLiveEvents.prototype.on = function(fn) {
                this.listeners.push(fn);
              };

              HecksLiveEvents.prototype.updateIndicator = function() {
                var btn = document.getElementById('hecks-live-toggle');
                if (!btn) return;
                if (this.connected) {
                  btn.className = 'hecks-live-toggle';
                  btn.querySelector('.label').textContent = 'Live';
                } else {
                  btn.className = 'hecks-live-toggle disconnected';
                  btn.querySelector('.label').textContent = 'Offline';
                }
              };

              HecksLiveEvents.prototype.renderPanel = function() {
                var panel = document.getElementById('hecks-live-panel');
                if (!panel) return;
                if (this.events.length === 0) {
                  panel.innerHTML = '<div class="empty">No events yet</div>';
                  return;
                }
                var html = '';
                for (var i = this.events.length - 1; i >= 0; i--) {
                  var ev = this.events[i];
                  var time = ev.occurred_at ? ev.occurred_at.split('T')[1].split('.')[0] : '';
                  html += '<div class="event-line"><span class="event-type">' + ev.type + '</span><span class="event-time">' + time + '</span></div>';
                }
                panel.innerHTML = html;
              };

              // Auto-init
              window.HecksLiveEvents = HecksLiveEvents;
              document.addEventListener('DOMContentLoaded', function() {
                window.hecksLive = new HecksLiveEvents();

                var toggle = document.getElementById('hecks-live-toggle');
                var panel = document.getElementById('hecks-live-panel');
                if (toggle && panel) {
                  toggle.addEventListener('click', function() {
                    panel.classList.toggle('open');
                  });
                }
              });
            })();
          </script>
        HTML
      end

      # Returns the HTML for the live events indicator widget.
      #
      # @return [String] HTML for the fixed-position indicator
      def self.indicator_html
        <<~HTML
          <div class="hecks-live">
            <div id="hecks-live-panel" class="hecks-live-panel">
              <div class="empty">No events yet</div>
            </div>
            <button id="hecks-live-toggle" class="hecks-live-toggle">
              <span class="dot"></span>
              <span class="label">Live</span>
            </button>
          </div>
        HTML
      end
    end
  end
end
