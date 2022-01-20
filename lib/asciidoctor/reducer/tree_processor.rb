# frozen_string_literal: true

module Asciidoctor::Reducer
  class TreeProcessor < ::Asciidoctor::Extensions::TreeProcessor
    def process doc
      return if doc.options[:reduced]
      if (inc_replacements = doc.reader.instance_variable_get :@x_include_replacements).length > 1
        inc_replacements[0][:lines] = doc.source_lines.dup
        inc_replacements.reverse_each do |it|
          next unless (into = it[:into])
          target_lines = inc_replacements[into][:lines]
          # adds extra bit of assurance that we're replacing the correct line
          next unless target_lines[(index = it[:index])] == it[:replace]
          target_lines[index..index] = it[:lines]
        end
        # WARNING: if include directives remain that can still be resolved, the sourcemap won't match the source lines
        doc = ::Asciidoctor.load inc_replacements[0][:lines], (doc.options.merge reduced: true)
      end
      ::Asciidoctor::LoggerManager.logger = ::Asciidoctor::LoggerManager.instance_variable_get :@original_logger
      ::Asciidoctor::LoggerManager.remove_instance_variable :@original_logger
      doc
    end
  end
end
