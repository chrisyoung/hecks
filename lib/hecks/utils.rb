module Hecks
  module Utils
    module_function

    def underscore(str)
      str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .downcase
    end

    def type_label(attr)
      if attr.list?
        "list_of(#{attr.type})"
      elsif attr.reference?
        "reference_to(#{attr.type})"
      else
        attr.type.to_s
      end
    end

    def block_source(block)
      return "true" unless block
      file, start_line = block.source_location
      lines = File.readlines(file)

      # Single-line block: `query "Foo" do where(x: 1) end`
      first = lines[start_line - 1].strip
      if first.match?(/\bdo\b.*\bend\s*$/)
        return first.sub(/^.*?\bdo\s*(\|[^|]*\|\s*)?/, "").sub(/\s*end\s*$/, "").strip
      end

      # Multi-line block: collect body lines between do and end
      body_lines = []
      depth = 0
      lines[start_line..-1].each do |l|
        stripped = l.strip
        break if depth == 0 && stripped == "end"
        body_lines << stripped
        depth += 1 if stripped.match?(/\b(do|def|class|module|if|unless|case|begin)\b/)
        depth -= 1 if stripped == "end"
      end
      body_lines.reject(&:empty?).join("\n")
    rescue StandardError
      "true"
    end
  end
end
