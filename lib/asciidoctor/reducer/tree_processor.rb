# frozen_string_literal: true

module Asciidoctor::Reducer
  class TreeProcessor < ::Asciidoctor::Extensions::TreeProcessor
    def process doc
      if (inc_replacements = doc.reader.include_replacements).size > 1 || !(inc_replacements[0][:drop] || []).empty?
        inc_replacements[0][:lines] = doc.source_lines.dup
        inc_replacements.reverse_each do |it|
          if (into = it[:into])
            target_lines = inc_replacements[into][:lines]
            # adds extra assurance that the program is replacing the correct line
            unless target_lines[(idx = it[:lineno] - 1)] == it[:line]
              msg = %(include directive to reduce not found; expected: "#{it[:line]}"; got: "#{target_lines[idx]}")
              doc.logger.error msg
              next
            end
          end
          lines = it[:lines]
          unless (drop = it[:drop] || []).empty?
            drop.reverse_each do |drop_it|
              ::Array === drop_it ? (lines[drop_it[0] - 1] = drop_it[1]) : (lines.delete_at drop_it - 1)
            end
          end
          target_lines[idx] = lines if target_lines
        end
        reduced_source_lines = inc_replacements[0][:lines].flatten
        if doc.sourcemap
          logger = doc.logger
          opts = doc.options.merge logger: nil, parse: false, reduced: true
          if (ext_reg = opts[:extension_registry])
            opts[:extension_registry] = ::Asciidoctor::Extensions::Registry.new ext_reg.groups
          end
          includes = doc.catalog[:includes]
          doc = ::Asciidoctor.load reduced_source_lines, opts
          doc.catalog[:includes] = includes
          doc.parse
          ::Asciidoctor::LoggerManager.logger = logger
        else
          reduced_source_lines.pop while reduced_source_lines[-1] == ''
          doc.source_lines.replace reduced_source_lines
        end
      end
      doc
    end
  end
end
