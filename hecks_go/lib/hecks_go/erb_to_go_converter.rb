# HecksGo::ErbToGoConverter
#
# Converts ERB templates to Go html/template syntax at generation time.
# Handles the common patterns used in the web explorer ERB views.
# Run once during `hecks build --target go`, not at request time.
#
#   converter = ErbToGoConverter.new
#   go_template = converter.convert("layout", erb_source)
#
module HecksGo
  class ErbToGoConverter
    # Convert an ERB template to Go html/template syntax.
    #
    # @param name [String] template name (used in {{ define "name" }})
    # @param erb [String] ERB source
    # @return [String] Go template source
    def convert(name, erb)
      go = erb.dup

      # Wrap non-layout templates in {{ define "name" }}
      unless name == "layout"
        go = "{{ define \"#{name}\" }}\n#{go}{{ end }}\n"
      else
        go = "{{ define \"layout\" }}#{go}{{ end }}\n"
      end

      # ERB output tags: <%= expr %> → {{ .Expr }} or {{ expr }}
      go.gsub!(/<%= content %>/, '{{ .Content }}')
      go.gsub!(/<%= brand %>/, '{{ .Brand }}')
      go.gsub!(/<%= title %>/, '{{ .Title }}')
      go.gsub!(/<%= domain_name %>/, '{{ .DomainName }}')
      go.gsub!(/<%= aggregate_name %>/, '{{ .AggregateName }}')
      go.gsub!(/<%= command_name %>/, '{{ .CommandName }}')
      go.gsub!(/<%= back_href %>/, '{{ .BackHref }}')
      go.gsub!(/<%= action %>/, '{{ .Action }}')
      go.gsub!(/<%= error_message %>/, '{{ .ErrorMessage }}')
      go.gsub!(/<%= event_count %>/, '{{ .EventCount }}')
      go.gsub!(/<%= booted_at %>/, '{{ .BootedAt }}')
      go.gsub!(/<%= current_role %>/, '{{ .CurrentRole }}')
      go.gsub!(/<%= current_adapter %>/, '{{ .CurrentAdapter }}')

      # Items/collections size: <%= items.size %>
      go.gsub!(/<%= items\.size %>/, '{{ len .Items }}')

      # Hash access: <%= item[:field] %> → {{ .Field }}
      go.gsub!(/<%= (\w+)\[:(\w+)\] %>/) { "{{ .#{pascal($2)} }}" }

      # Simple variable output: <%= var %>
      go.gsub!(/<%= (\w+) %>/) { "{{ .#{pascal($1)} }}" }

      # Dot access: <%= obj.field %> → {{ .Field }}
      go.gsub!(/<%= (\w+)\.(\w+) %>/) { "{{ .#{pascal($2)} }}" }

      # Each loops: <% items.each do |item| %> → {{ range .Items }}
      go.gsub!(/<% (\w+)\.each do \|(\w+)\| %>/) { "{{ range .#{pascal($1)} }}" }

      # If with hash: <% if item[:field] %> → {{ if .Field }}
      go.gsub!(/<% if (\w+)\[:(\w+)\] %>/) { "{{ if .#{pascal($2)} }}" }

      # If comparison: <% if x == y %> → {{ if eq .X .Y }}
      go.gsub!(/<% if (\w+) == (\w+) %>/) { "{{ if eq .#{pascal($1)} .#{pascal($2)} }}" }

      # Complex if: <% if x[:field] && x[:field] > 0 %> → {{ if gt .Field 0 }}
      go.gsub!(/<% if (\w+)\[:(\w+)\] && \w+\[:(\w+)\] > 0 %>/) { "{{ if gt .#{pascal($2)} 0 }}" }

      # Defined check: <% if defined?(var) && var && !var.empty? %> → {{ if .Var }}
      go.gsub!(/<% if defined\?\((\w+)\) && (\w+) && !(\w+)\.empty\? %>/) { "{{ if .#{pascal($1)} }}" }

      # Unless: <% unless condition %> → {{ if not .Condition }}
      go.gsub!(/<% unless (\w+)\[:(\w+)\] %>/) { "{{ if not .#{pascal($2)} }}" }
      go.gsub!(/<% unless (\w+) %>/) { "{{ if not .#{pascal($1)} }}" }

      # If with method: <% if field[:allowed] %> → {{ if .Allowed }}
      # Already handled above

      # Conditional class: <%= ' selected' if r == current_role %>
      go.gsub!(/<%= ' selected' if (\w+) == (\w+) %>/) { "{{ if eq . $.#{pascal($2)} }} selected{{ end }}" }

      # Conditional CSS class with hash: <%= ' btn-faded' unless btn[:allowed] %>
      go.gsub!(/<%= ' (\w[\w-]*)' unless (\w+)\[:(\w+)\] %>/) { "{{ if not .#{pascal($3)} }} #{$1}{{ end }}" }

      # Group/section pattern from layout sidebar
      go.gsub!(/<% group = item\[:group\].*%>/, '')
      go.gsub!(/<% if group && group != last_group %>/, '{{ if and .Group (ne .Group $lastGroup) }}')
      go.gsub!(/<% last_group = group %>/, '{{ $lastGroup = .Group }}')
      go.gsub!(/<% last_group = nil %>/, '{{ $lastGroup := "" }}')

      # End tags
      go.gsub!(/<% end %>/, '{{ end }}')

      # Next/skip: <% next if ... %> — remove (Go range doesn't have next)
      go.gsub!(/<% next.*%>/, '')

      # Remaining ERB tags that weren't caught — comment them
      go.gsub!(/<%=?\s*(.+?)\s*%>/) { "{{/* ERB: #{$1} */}}" }

      # Clean up blank lines
      go.gsub!(/\n{3,}/, "\n\n")

      go
    end

    private

    def pascal(str)
      str.to_s.split("_").map(&:capitalize).join
    end
  end
end
