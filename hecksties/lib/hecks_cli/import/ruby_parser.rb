module Hecks
  module Import
    # Hecks::Import::RubyParser
    #
    # Scans Ruby source files via regex (no require, no eval) and extracts
    # class structure: modules, superclasses, attributes, Struct/Data members,
    # and nested classes. Works on any Ruby project — POROs, Structs, Data
    # classes, gems, scripts. No Rails dependency.
    #
    #   RubyParser.new("/path/to/lib").parse
    #   # => [{ name: "Order", module: "Billing", superclass: nil,
    #   #       attributes: [{name: "total", type: "String"}],
    #   #       nested_classes: [{name: "LineItem", ...}] }]
    #
    class RubyParser
      def initialize(path)
        @path = path
      end

      def parse
        ruby_files.flat_map { |f| parse_file(f) }
      end

      private

      def ruby_files
        Dir[File.join(@path, "**", "*.rb")].sort
      end

      def parse_file(path)
        content = File.read(path)
        classes = extract_classes(content)
        classes.reject { |c| c[:name].nil? }
      end

      def extract_classes(content)
        results = []
        modules = []
        # Stack tracks what each nesting level is: :module, :class, or :other
        stack = []
        content.each_line do |line|
          stripped = line.strip
          next if stripped.start_with?("#")

          if (mod = stripped.match(/\Amodule\s+([A-Z][\w:]*)/))
            modules.push(mod[1])
            stack.push(:module)
          elsif (cls = parse_class_line(stripped))
            cls[:module] = modules.join("::") unless modules.empty?
            cls[:attributes] ||= []
            cls[:nested_classes] ||= []
            extract_body_info(content, cls)
            results << cls
            stack.push(:class)
          elsif opens_block?(stripped)
            stack.push(:other)
          elsif end_line?(stripped) && stack.any?
            kind = stack.pop
            modules.pop if kind == :module
          end
        end
        results
      end

      def parse_class_line(line)
        # class Foo::Bar < Struct.new(:x, :y)
        if (m = line.match(/\Aclass\s+([A-Z][\w:]*)\s*<\s*Struct\.new\(([^)]*)\)/))
          { name: short_name(m[1]), superclass: "Struct", attributes: parse_members(m[2]) }
        # class Foo < Data.define(:x, :y)
        elsif (m = line.match(/\Aclass\s+([A-Z][\w:]*)\s*<\s*Data\.define\(([^)]*)\)/))
          { name: short_name(m[1]), superclass: "Data", attributes: parse_members(m[2]) }
        # class Foo < SomeParent
        elsif (m = line.match(/\Aclass\s+([A-Z][\w:]*)\s*<\s*([A-Z][\w:]*)/))
          { name: short_name(m[1]), superclass: m[2] }
        # class Foo (plain class)
        elsif (m = line.match(/\Aclass\s+([A-Z][\w:]*)\s*$/))
          { name: short_name(m[1]) }
        end
      end

      def parse_members(args_str)
        args_str.scan(/:(\w+)/).flatten.map { |n| { name: n, type: "String" } }
      end

      def short_name(full_name)
        full_name.split("::").last
      end

      def extract_body_info(content, cls)
        extract_attr_declarations(content, cls)
        extract_nested_classes(content, cls)
      end

      def extract_attr_declarations(content, cls)
        existing = cls[:attributes].map { |a| a[:name] }
        content.scan(/attr_(?:accessor|reader)\s+(.+)$/) do |match|
          match[0].scan(/:(\w+)/).flatten.each do |attr_name|
            next if existing.include?(attr_name)
            cls[:attributes] << { name: attr_name, type: "String" }
            existing << attr_name
          end
        end
      end

      def extract_nested_classes(content, cls)
        in_class = false
        depth = 0
        content.each_line do |line|
          stripped = line.strip
          if !in_class && stripped.match?(/\Aclass\s+#{Regexp.escape(cls[:name])}\b/)
            in_class = true
            depth = 1
            next
          end
          next unless in_class

          depth += count_opens(stripped)
          depth -= 1 if end_line?(stripped)

          if depth > 1 && (nested = parse_class_line(stripped))
            nested[:module] = nil
            nested[:attributes] ||= []
            nested[:nested_classes] = []
            cls[:nested_classes] << nested
          end

          break if depth <= 0
        end
      end

      def opens_block?(line)
        line.match?(/\b(def|do|if|unless|case|begin)\b/) && !end_line?(line)
      end

      def count_opens(line)
        opens = 0
        opens += 1 if line.match?(/\b(class|module|def|do|if|unless|case|begin)\b/) && !end_line?(line)
        opens
      end

      def end_line?(line)
        line.match?(/\Aend\b/)
      end
    end
  end
end
