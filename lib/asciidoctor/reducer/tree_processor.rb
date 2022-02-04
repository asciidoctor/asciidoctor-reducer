# frozen_string_literal: true

module Asciidoctor::Reducer
  class TreeProcessor < ::Asciidoctor::Extensions::TreeProcessor
    def process doc
      return if doc.options[:reduced]
      inc_replacements = doc.reader.x_include_replacements
      unless inc_replacements.length == 1 && inc_replacements[0][:drop].empty?
        inc_replacements[0][:lines] = doc.source_lines.dup
        inc_replacements.reverse_each do |it|
          if (into = it[:into])
            target_lines = inc_replacements[into][:lines]
            # adds extra bit of assurance that we're replacing the correct line
            next unless target_lines[(index = it[:index])] == it[:replace]
          end
          lines = it[:lines]
          unless (drop = it[:drop]).empty?
            drop.reverse_each {|idx| ::Array === idx ? (lines[idx[0]] = idx[1]) : (lines.delete_at idx) }
          end
          target_lines[index] = lines if target_lines
        end
        source_lines = inc_replacements[0][:lines].flatten
        if doc.sourcemap
          # WARNING: if include directives remain that can still be resolved, the sourcemap won't match the source lines
          doc = ::Asciidoctor.load source_lines, (doc.options.merge reduced: true)
        else
          source_lines.pop while (last = source_lines[-1]) && last.empty?
          doc.reader.source_lines = source_lines
        end
      end
      doc
    end
  end
end
