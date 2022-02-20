# frozen_string_literal: true

module Asciidoctor::Reducer
  class TreeProcessor < ::Asciidoctor::Extensions::TreeProcessor
    def process doc
      unless (inc_replacements = doc.reader.x_include_replacements).length == 1 && inc_replacements[0][:drop].empty?
        inc_replacements[0][:lines] = doc.source_lines.dup
        inc_replacements.reverse_each do |it|
          if (into = it[:into])
            target_lines = inc_replacements[into][:lines]
            # adds extra bit of assurance that we're replacing the correct line
            next unless target_lines[(idx = it[:lineno])] == it[:line]
          end
          lines = it[:lines]
          unless (drop = it[:drop]).empty?
            drop.reverse_each {|it| ::Array === it ? (lines[it[0]] = it[1]) : (lines.delete_at it) }
          end
          target_lines[idx] = lines if target_lines
        end
        source_lines = inc_replacements[0][:lines].flatten
        if doc.sourcemap
          logger = ::Asciidoctor::LoggerManager.logger
          opts = doc.options.merge logger: nil, parse: false, reduced: true
          if (ext_reg = opts[:extension_registry])
            opts[:extension_registry] = ::Asciidoctor::Extensions::Registry.new ext_reg.groups
          end
          includes = doc.catalog[:includes]
          doc = ::Asciidoctor.load source_lines, opts
          doc.catalog[:includes] = includes
          doc.parse
          ::Asciidoctor::LoggerManager.logger = logger
        else
          source_lines.pop while (source_lines[-1] || :eof).empty?
          doc.reader.source_lines = source_lines
        end
      end
      doc
    end
  end
end
