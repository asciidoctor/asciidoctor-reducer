# frozen_string_literal: true

module Asciidoctor::Reducer
  class TreeProcessor < ::Asciidoctor::Extensions::TreeProcessor
    def process doc
      return if doc.options[:reduced]
      unless (inc_replacements = doc.reader.instance_variable_get :@x_include_replacements).empty?
        resolved_source_lines = doc.source_lines.dup
        inc_replacements.reverse_each do |it|
          # when into is -1, it indicates this is a top-level include
          target_lines = (into = it[:into]) < 0 ? resolved_source_lines : inc_replacements[into][:lines]
          # adds extra bit of assurance that we're replacing the correct line
          if target_lines[(index = it[:index])] == it[:replace]
            target_lines[index..index] = it[:lines]
          end
        end
        # WARNING: if include directives remain that can still be resolved, the sourcemap won't match the source lines
        doc = ::Asciidoctor.load resolved_source_lines, (doc.options.merge sourcemap: true, reduced: true)
      end
      ::Asciidoctor::LoggerManager.logger = ::Asciidoctor::LoggerManager.instance_variable_get :@original_logger
      ::Asciidoctor::LoggerManager.remove_instance_variable :@original_logger
      doc
    end
  end
end
