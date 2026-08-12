module Hecksagain
  module Bluebook
    module DSL
      class HecksagonBuilder
        class << self
          attr_accessor :collector
        end

        attr_reader :binds, :subscriptions, :framework_members, :raw_adapters, :driving_handlers

        def initialize(domain)
          @domain             = domain
          @binds              = []
          @subscriptions      = []
          @framework_members  = []
          @raw_adapters       = []
          @driving_handlers   = []
        end

        # Vendored addition, not (yet) upstream hecksagain (task 7 of the
        # migration plan): `adapter "Name" do driving on <kind> "<arg>"
        # do |signal| dispatch "Domain::Aggregate.Command" end end` --
        # the DRIVING-SIDE construct (an external clock/file-watch/
        # http-post reaches IN, the inverse of persisted_by/charged_by's
        # driven-side). Confirmed real, live, 32 files in hecks_conception
        # (cron_adapter.hecksagon, agent_inbox.hecksagon,
        # event_sourcing.hecksagon, ...), grammar already proven in TWO
        # other Hecks codebases (rust/src/hecksagon_parser.rs::
        # parse_driving_handler, ruby/hecksagon/dsl/driven_adapter_builder.rb)
        # -- ported here, not invented. STRUCTURAL support only: the
        # actual clock that fires these on a schedule is a SEPARATE
        # concern (Part 1 item 8 of the plan -- keep the old Rust
        # driving-loop process alive, targeting hecksagain-cli's
        # dispatch subcommand, until a Ruby scheduler is built) --
        # documented, not silently pretended complete.
        #
        # ALSO still handles the OLD `adapter :symbol, key: val, ...`
        # form (67+ files) when called with no block -- same method,
        # dispatches on block presence. NEITHER shape had ANY handler at
        # all before this -- a bare `adapter :symbol, key: val` with no
        # block inside a hecksagon raised a plain NoMethodError, not a
        # refusal, on all 67+ files using it. Bundled into one PR/one
        # method rather than split further: both branches are genuinely
        # new capability sharing one dispatch surface (block presence),
        # not two features that happened to land together -- no partial
        # form of this method ever existed to split around. (The THIRD
        # branch this same method gains in the real source commit --
        # `:heki`/`:memory`/`:sqlite` domain-wide persisted_by defaults --
        # is its own, later, independently-meaningful PR: it carries its
        # own DEFERRED-apply subtlety and its own migration-plan citation,
        # not fabricated as separate, just genuinely a third concern
        # layered onto the same no-block branch.)
        def adapter(kind, **opts, &block)
          return @raw_adapters << { kind: kind.to_s, opts: opts } unless block

          @driving_handlers.concat(DrivingAdapterBuilder.build(kind, &block))
        end

        # An event this hecksagon takes from OUTSIDE the domain's own
        # bluebook.
        def subscribe(event) = @subscriptions << event.to_s

        # A framework/ member this domain wants attached —
        # Governance, Identity, whatever else lands beside them.
        # Attaching one is a WIRING decision, the same kind `persisted_by`/
        # `projected_by` already are, so it lives here rather than as a
        # fact stated in the domain's own bluebook. Recorded onto THIS
        # hecksagon, the same way `subscribe` records onto its own
        # `subscriptions` — and loads the member's bluebook then its own
        # hecksagon into whatever registry this one is loading into, see
        # `Framework.load!`.
        def uses_framework(name)
          @framework_members << name.to_s
          Hecksagain::Framework.load!(name)
        end

        # THE PRIMARY PORT, BARE AT THE ROOT — belongs to the CHAPTER as a
        # whole, not one aggregate. `BindingProxy#port` is the aggregate-
        # scoped sibling (`Payments::Payment.port("Gateway") do ... end`);
        # this is what's left when a port isn't about any one record. The
        # bluebook must already be built and registered, since a hecksagon
        # loads after its bluebook, and this attaches to that real, final
        # object directly rather than building a second copy MetaValidator
        # would have to know how to reconstruct.
        def port(name, &block)
          bluebook_ir = Hecksagain.current_registry.bluebook(@domain) or
            raise Malformed, "#{@domain} declares no such bluebook — a port needs one to belong to"

          # See BindingProxy#port's own comment on why this resolver swap is
          # needed — ConstShim's active resolver is one global for the whole
          # dynamic extent, currently this file's own BindingProxy-minting
          # one, which would turn a bare constant inside an operation's
          # `reference_to`/`attribute` into another BindingProxy instead of
          # a name.
          built = ConstShim.with(->(const) { const }) { DomainPortBuilder.build(name, &block) }

          # See BindingProxy#port's own comment on the same branch — a
          # `verb`-shaped port is a plain `IR::Port`, registered the same
          # way `Hecks.port`'s top-level method already does, not attached
          # to this bluebook's own IR the way an operations-shaped
          # `IR::DomainPort` is.
          return Hecksagain.current_registry.add_port(built) if built.is_a?(IR::Port)

          bluebook_ir.add_port(built)
        end

        def build
          IR::Hecksagon.new(domain: @domain, binds: @binds, subscriptions: @subscriptions,
                             framework_members: @framework_members, driving_handlers: @driving_handlers)
        end

        def self.build(domain, &block)
          builder  = new(domain)
          resolver = ->(name) { BindingProxy.namespace(name, builder.binds) }

          previous       = collector
          self.collector = builder.binds
          begin
            ConstShim.with(resolver) { builder.instance_eval(&block) } if block
          ensure
            self.collector = previous
          end

          builder.build
        end
      end
    end
  end
end
