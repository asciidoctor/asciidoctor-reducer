# frozen_string_literal: true

unless (Pathname.instance_method :rmtree).arity > 0
  autoload :FileUtils, 'fileutils'
  Pathname.prepend (Module.new do
    def rmtree **kwargs
      FileUtils.rm_rf @path, **kwargs
      nil
    end
  end)
end
