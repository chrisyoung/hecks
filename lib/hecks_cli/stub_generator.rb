# Hecks::CLI::StubGenerator
#
# Resolves a domain element by type and name, runs the appropriate code
# generator, and returns a hash of { file_path => content } for writing.
# Supports command, query, aggregate, workflow, service, policy, and
# specification types.
#
#   gen = StubGenerator.new(domain, "command", "Withdraw")
#   gen.generate  # => { "lib/banking_domain/account/commands/withdraw.rb" => "..." }
#
module Hecks
  class CLI < Thor
    class StubGenerator
      def initialize(domain, type, name)
        @domain = domain
        @type = type
        @name = name
        @gem = domain.gem_name
        @mod = domain.module_name + "Domain"
      end

      def generate
        case @type
        when "command"    then generate_command
        when "query"      then generate_query
        when "aggregate"  then generate_aggregate
        when "workflow"   then generate_workflow
        when "service"    then generate_service
        when "policy"     then generate_policy
        when "specification" then generate_specification
        end
      end

      private

      def generate_command
        agg, cmd, idx = find_command
        return error_not_found("command", @name) unless cmd
        event = agg.events[idx]
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        src = gen(Generators::Domain::CommandGenerator, cmd,
                  domain_module: @mod, aggregate_name: safe, aggregate: agg, event: event)
        { path_for(snake, "commands", cmd.name) => src }
      end

      def generate_query
        agg, query = find_in_aggregates(:queries)
        return error_not_found("query", @name) unless query
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        src = gen(Generators::Domain::QueryGenerator, query,
                  domain_module: @mod, aggregate_name: safe)
        { path_for(snake, "queries", query.name) => src }
      end

      def generate_policy
        agg, policy = find_in_aggregates(:policies)
        return error_not_found("policy", @name) unless policy
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        src = gen(Generators::Domain::PolicyGenerator, policy,
                  domain_module: @mod, aggregate_name: safe)
        { path_for(snake, "policies", policy.name) => src }
      end

      def generate_specification
        agg, spec = find_in_aggregates(:specifications)
        return error_not_found("specification", @name) unless spec
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        src = gen(Generators::Domain::SpecificationGenerator, spec,
                  domain_module: @mod, aggregate_name: safe)
        { path_for(snake, "specifications", spec.name) => src }
      end

      def generate_aggregate
        agg = @domain.aggregates.find { |a| a.name == @name }
        return error_not_found("aggregate", @name) unless agg
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        files = {}
        files[path_for(snake, nil, agg.name)] =
          gen(Generators::Domain::AggregateGenerator, agg, domain_module: @mod)
        agg.commands.each_with_index do |cmd, i|
          files[path_for(snake, "commands", cmd.name)] =
            gen(Generators::Domain::CommandGenerator, cmd,
                domain_module: @mod, aggregate_name: safe, aggregate: agg, event: agg.events[i])
        end
        files
      end

      def generate_workflow
        wf = @domain.workflows.find { |w| w.name == @name }
        return error_not_found("workflow", @name) unless wf
        src = Generators::Domain::WorkflowGenerator.new(wf, domain_module: @mod).generate
        { "lib/#{@gem}/workflows/#{Hecks::Utils.underscore(wf.name)}.rb" => src }
      end

      def generate_service
        svc = @domain.services.find { |s| s.name == @name }
        return error_not_found("service", @name) unless svc
        src = Generators::Domain::ServiceGenerator.new(svc, domain_module: @mod).generate
        { "lib/#{@gem}/services/#{Hecks::Utils.underscore(svc.name)}.rb" => src }
      end

      def find_command
        @domain.aggregates.each do |agg|
          agg.commands.each_with_index do |cmd, i|
            return [agg, cmd, i] if cmd.name == @name
          end
        end
        nil
      end

      def find_in_aggregates(collection)
        @domain.aggregates.each do |agg|
          item = agg.send(collection).find { |x| x.name == @name }
          return [agg, item] if item
        end
        [nil, nil]
      end

      def gen(klass, obj, **opts) = klass.new(obj, **opts).generate

      def path_for(agg_snake, subdir, name)
        snake_name = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(name))
        parts = ["lib", @gem, agg_snake]
        parts << subdir if subdir
        parts << "#{snake_name}.rb"
        File.join(*parts)
      end

      def error_not_found(type, name)
        $stderr.puts "No #{type} '#{name}' found in #{@domain.name}"
        nil
      end
    end
  end
end
