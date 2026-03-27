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

      # Simple variable in range context: <%= cell %> inside range .Cells → {{ . }}
      # (handled by keeping simple var output and letting Go figure it out)

      # Simple variable output: <%= var %>
      go.gsub!(/<%= (\w+) %>/) { "{{ .#{pascal($1)} }}" }

      # Dot access: <%= obj.field %> → {{ .Field }}
      go.gsub!(/<%= (\w+)\.(\w+) %>/) { "{{ .#{pascal($2)} }}" }

      # Each loops: <% items.each do |item| %> → {{ range .Items }}
      go.gsub!(/<% (\w+)\.each do \|(\w+)\| %>/) { "{{ range .#{pascal($1)} }}" }

      # Hash each with nested access: <% item[:cells].each do |cell| %> → {{ range .Cells }}
      go.gsub!(/<% (\w+)\[:(\w+)\]\.each do \|(\w+)\| %>/) { "{{ range .#{pascal($2)} }}" }

      # Collection any?: <% if items.any? %> → {{ if .Items }}
      go.gsub!(/<% if (\w+)\.any\? %>/) { "{{ if .#{pascal($1)} }}" }

      # Collection empty?: <% if items.empty? %> → {{ if not .Items }}
      go.gsub!(/<% if (\w+)\.empty\? %>/) { "{{ if not .#{pascal($1)} }}" }

      # If hash == symbol: <% if field[:type] == :hidden %> → {{ if eq .Type "hidden" }}
      go.gsub!(/<% if (\w+)\[:(\w+)\] == :(\w+) %>/) { "{{ if eq .#{pascal($2)} \"#{$3}\" }}" }

      # Elsif hash == symbol: <% elsif field[:type] == :select %> → {{ else if eq .Type "select" }}
      go.gsub!(/<% elsif (\w+)\[:(\w+)\] == :(\w+) %>/) { "{{ else if eq .#{pascal($2)} \"#{$3}\" }}" }

      # Else: <% else %> → {{ else }}
      go.gsub!(/<% else %>/, '{{ else }}')

      # If with hash: <% if item[:field] %> → {{ if .Field }}
      go.gsub!(/<% if (\w+)\[:(\w+)\] %>/) { "{{ if .#{pascal($2)} }}" }

      # If comparison: <% if x == y %> → {{ if eq .X .Y }}
      go.gsub!(/<% if (\w+) == (\w+) %>/) { "{{ if eq .#{pascal($1)} .#{pascal($2)} }}" }

      # Complex if: <% if x[:field] && x[:field] > 0 %> → {{ if gt .Field 0 }}
      go.gsub!(/<% if (\w+)\[:(\w+)\] && \w+\[:(\w+)\] > 0 %>/) { "{{ if gt .#{pascal($2)} 0 }}" }

      # Defined check: <% if defined?(var) && var && !var.empty? %> → {{ if .Var }}
      go.gsub!(/<% if defined\?\((\w+)\) && (\w+) && !(\w+)\.empty\? %>/) { "{{ if .#{pascal($1)} }}" }

      # Simple if: <% if var %> → {{ if .Var }}
      go.gsub!(/<% if (\w+) %>/) { "{{ if .#{pascal($1)} }}" }

      # Unless: <% unless condition %> → {{ if not .Condition }}
      go.gsub!(/<% unless (\w+)\[:(\w+)\] %>/) { "{{ if not .#{pascal($2)} }}" }
      go.gsub!(/<% unless (\w+) %>/) { "{{ if not .#{pascal($1)} }}" }

      # If with method: <% if field[:allowed] %> → {{ if .Allowed }}
      # Already handled above

      # Conditional class: <%= ' selected' if r == current_role %>
      go.gsub!(/<%= ' selected' if (\w+) == (\w+) %>/) { "{{ if eq . $.#{pascal($2)} }} selected{{ end }}" }

      # Conditional CSS class with hash: <%= ' btn-faded' unless btn[:allowed] %>
      go.gsub!(/<%= ' (\w[\w-]*)' unless (\w+)\[:(\w+)\] %>/) { "{{ if not .#{pascal($3)} }} #{$1}{{ end }}" }

      # Inline conditional attribute: <%= ' step="any"' if field[:step] %>
      go.gsub!(/<%= '([^']*)' if (\w+)\[:(\w+)\] %>/) { "{{ if .#{pascal($3)} }}#{$1}{{ end }}" }

      # Default value: <%= field[:input_type] || 'text' %> → {{ or .InputType "text" }}
      go.gsub!(/<%= (\w+)\[:(\w+)\] \|\| '(\w+)' %>/) { "{{ or .#{pascal($2)} \"#{$3}\" }}" }

      # Inline conditional with hash if: <% if field[:required] %><span...><% end %>
      # Already handled by if/end conversion above

      # Group/section pattern from layout sidebar
      go.gsub!(/<% group = item\[:group\].*%>/, '')
      go.gsub!(/<% if group && group != last_group %>/, '{{ if and .Group (ne .Group $lastGroup) }}')
      go.gsub!(/<% last_group = group %>/, '{{ $lastGroup = .Group }}')
      go.gsub!(/<% last_group = nil %>/, '{{ $lastGroup := "" }}')

      # End tags
      go.gsub!(/<% end %>/, '{{ end }}')

      # Next/skip: <% next if ... %> — remove (Go range doesn't have next)
      go.gsub!(/<% next.*%>/, '')

      # Remove unconverted ERB blocks (if/each that didn't match) and their end tags
      # Match: remaining <% ... %> that has a corresponding <% end %>
      lines = go.lines
      skip_depth = 0
      cleaned = []
      lines.each do |line|
        if line =~ /<%[^=].*%>/ && skip_depth == 0
          # Unconverted ERB control tag — start skipping
          skip_depth = 1
        elsif skip_depth > 0
          skip_depth += 1 if line =~ /\{\{ (?:range|if) /
          if line.strip == '{{ end }}'
            skip_depth -= 1
            next if skip_depth == 0
          end
          next if skip_depth > 0
        end
        cleaned << line unless line =~ /<%.*%>/
      end
      go = cleaned.join

      # Any remaining ERB output tags — just remove
      go.gsub!(/<%= .+? %>/, '')

      # Inside {{ range .Cells }}, the loop var is just {{ . }} not {{ .Cell }}
      # Same for any range over a simple array where the block var matches the collection singular
      go.gsub!(/\{\{ range \.(\w+) \}\}(.*?)\{\{ \.(\w+) \}\}/m) do |match|
        collection = $1
        body = $2
        field = $3
        singular = collection.sub(/s$/, "")
        if field.downcase == singular.downcase
          "{{ range .#{collection} }}#{body}{{ . }}"
        else
          match
        end
      end

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
