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
      file, line = block.source_location
      lines = File.readlines(file)
      source_line = lines[line - 1].strip
      source_line.sub(/^invariant.*do\s*/, "").sub(/\s*end\s*$/, "")
    rescue StandardError
      "true"
    end
  end
end
