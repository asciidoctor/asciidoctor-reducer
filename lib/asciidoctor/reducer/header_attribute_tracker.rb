# frozen_string_literal: true

module Asciidoctor::Reducer
  module HeaderAttributeTracker
    def self.extended instance
      return if instance.singleton_class.method_defined? :source_header_attributes
      instance.singleton_class.send :attr_reader, :source_header_attributes
    end

    def finalize_header(*)
      @source_header_attributes = @attributes_modified.each_with_object({}) do |name, accum|
        accum[name] = @attributes[name]
      end
      super
    end
  end
end
