# Hecks::Workbench::AggregateHandle::ImplicitSyntax
#
# method_missing-based one-line dot syntax for the REPL.
# Enables: Post.title String, Post.create, Post.Address { ... }
#
module Hecks
  class Workbench
    class AggregateHandle
      module ImplicitSyntax
        def method_missing(name, *args, **kwargs, &block)
          name_s = name.to_s

          if name_s =~ /\A[A-Z]/ && block_given?
            value_object(name_s, &block)
          elsif block_given?
            cmd_name = infer_command_name(name_s)
            command(cmd_name, &block)
          elsif args.first.is_a?(Class) || (args.first.is_a?(String) && args.first =~ /\A[A-Z]/)
            attr(name, args.first, **kwargs)
          elsif args.first.is_a?(Hash) && (args.first[:list] || args.first[:reference])
            attr(name, args.first, **kwargs)
          elsif args.empty? && kwargs.empty? && !block_given?
            cmd_name = infer_command_name(name_s)
            unless @command_handles.key?(cmd_name)
              command(cmd_name)
            end
            @command_handles[cmd_name] ||= CommandHandle.new(cmd_name, @builder, @name)
          else
            super
          end
        end

        def respond_to_missing?(name, include_private = false)
          true
        end
      end
    end
  end
end
