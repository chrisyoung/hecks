module Hecksagain
  module Bluebook
    module IR
      Port = Struct.new(:name, :verb, :signal, keyword_init: true) do
        def reply?  = signal == :reply
        def effect? = signal == :effect
      end

      Adapter = Struct.new(:name, :port, :fields, :secrets, keyword_init: true) do
        def declares?(field) = all_fields.include?(field.to_sym)

        def all_fields = (fields || []) + (secrets || [])
      end

      Bind = Struct.new(:aggregate, :verb, :adapter, :role, keyword_init: true) do
        def aggregate_name = Naming.demodulise(aggregate)
      end

      # Vendored addition, not (yet) upstream hecksagain (migration plan
      # task 7): a DRIVING-side handler -- an external clock/file-watch/
      # http-post reaching IN to fire a dispatch, the inverse of Bind's
      # driven-side edge. adapter_name names the `adapter "X" do ... end`
      # block it was declared in; kind is "cron"/"interval"/"http_post"/
      # "file_watch"; arg is the schedule/path/route string;
      # dispatch_command is the FQN the handler fires on tick.
      #
      # PULLED FORWARD from a much later commit in this same migration
      # (`03b5ffc`, "IR: driving-handler wire shape" -- split-plan item
      # 30) as real plumbing: DrivingAdapterBuilder#driving (this PR)
      # calls `IR::DrivingHandler.new(...)` directly, so without this
      # struct the driving-adapter grammar is unreachable dead code, the
      # same "plumbing ready before its feature" pattern as items
      # 07b/12e. Item 30, when it lands, is scoped down to `03b5ffc`'s
      # OTHER three pieces (the `Binding#for_binding` generic-settings
      # fallback bug, `category`, `Policy#with_literals`/Rendering fix) --
      # this hunk is already done.
      DrivingHandler = Struct.new(:adapter_name, :kind, :arg, :dispatch_command, keyword_init: true) do
        def to_h = { adapter_name: adapter_name, kind: kind, arg: arg, dispatch_command: dispatch_command }
      end

      class Hecksagon
        attr_reader :domain, :binds, :subscriptions, :framework_members, :driving_handlers

        def initialize(domain:, binds: [], subscriptions: [], framework_members: [], driving_handlers: [])
          @domain             = domain.to_s
          @binds              = binds
          @subscriptions      = subscriptions
          @framework_members  = framework_members
          @driving_handlers   = driving_handlers
        end

        def bind_for(aggregate_name, verb)
          @binds.find do |b|
            b.aggregate_name == aggregate_name.to_s && b.verb.to_s == verb.to_s
          end
        end

        def binds_for(aggregate_name, verb)
          @binds.select do |b|
            b.aggregate_name == aggregate_name.to_s && b.verb.to_s == verb.to_s
          end
        end

        def to_h
          { domain: @domain, binds: @binds.map(&:to_h), subscriptions: @subscriptions.map(&:to_s),
            framework_members: @framework_members.map(&:to_s),
            driving_handlers: @driving_handlers.map(&:to_h) }
        end
      end

      class World
        attr_reader :domain, :realm, :latest, :settings

        def initialize(domain:, realm: nil, latest: nil, settings: {})
          @domain   = domain.to_s
          @realm    = realm&.to_s
          @latest   = latest&.to_s
          @settings = settings
        end

        def for_verb(verb) = @settings.fetch(verb.to_s, {})

        def for_binding(verb, adapter)
          @settings.fetch("#{verb}:#{adapter.to_s.downcase}", for_verb(verb))
        end

        def to_h = { domain: @domain, realm: @realm, latest: @latest, settings: @settings }
      end
    end
  end
end
