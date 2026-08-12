require_relative "../../bluebook/dsl/binding_proxy"
require_relative "../../bluebook/dsl/hecksagon_builder"

module Hecksagain
  module Facade
    module Surface
      # One chapter's module: vision and aggregate roll-call on the
      # singleton, one aggregate door per declared head, and the
      # declaration hook for names the door does not carry.
      module Chapter
        def chapter_module(dispatcher, bluebook)
          chapter = Module.new
          chapter.define_singleton_method(:vision)     { bluebook.vision }
          chapter.define_singleton_method(:aggregates) { bluebook.aggregates.map(&:name).sort }
          # THE CHAPTER, EXPLAINING ITSELF. `Projector::DocsProjector` reads
          # nothing but this bluebook's own IR, so the document cannot drift
          # from the domain — the same guarantee `bin/reference` gives the DSL
          # reference by generating it from the Syntax chapter.
          #
          # A METHOD RATHER THAN ONLY A SCRIPT because that is what gets it
          # read: `QualityControl.docs` in a console, beside `vision` and
          # `aggregates`, at the moment somebody is wondering what a verb
          # wants. Projected on each call rather than memoised — it is a pure
          # read of the IR, and a stale document is the entire thing this
          # exists to prevent.
          chapter.define_singleton_method(:docs) do |**options|
            Projector.call(:docs, bluebook: bluebook, options: options)
          end

          bluebook.aggregates.each do |aggregate|
            chapter.const_set(aggregate.hecks_name, aggregate_module(dispatcher, bluebook.name, aggregate))
          end

          # INSIDE A HECKSAGON, A NAME IS A DECLARATION, NOT A LOOKUP. A
          # `.hecksagon` may name an aggregate this door does not carry — a STALE
          # door from an earlier boot resolving another registry's chapter, the
          # exact hazard the constant tree used to hide by reinstalling on every
          # load. With a collector open, the name becomes a `BindingProxy`
          # recording the same bind the aggregate module would ; without one, it
          # is a genuine NameError, exactly as before.
          chapter.define_singleton_method(:const_missing) do |name|
            collector = Bluebook::DSL::HecksagonBuilder.collector
            return super(name) unless collector

            Bluebook::DSL::BindingProxy.new("#{bluebook.name}::#{name}", collector)
          end

          chapter
        end
      end
    end
  end
end
