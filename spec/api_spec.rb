# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::Reducer do
  let :the_input_source do
    <<~'END'
    before include

    include::single-line-paragraph.adoc[]

    after include
    END
  end

  let :the_expected_source do
    <<~'END'
    before include

    single line paragraph

    after include
    END
  end

  context 'version' do
    it 'should provide VERSION constant' do
      (expect described_class::VERSION).to match %r/^\d+\.\d+\.\d+(\.\S+)?$/
    end
  end

  describe '.reduce' do
    subject { described_class.method :reduce }

    it 'should reduce input when no options are specified' do
      run_scenario do
        input_source <<~'END'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]
        END
        reduce { subject.call input_source }
        expected_source 'primary content'
      end
    end

    it 'should reduce input specified as File object' do
      scenario = create_scenario do
        input_source the_input_source
        reduce { File.open(input_file, mode: 'r:UTF-8') {|f| subject.call f } }
        expected_source the_expected_source
      end
      doc = scenario.run
      input_file = scenario.input_file
      (expect doc.attr 'docname').to eql (File.basename input_file, '.adoc')
      (expect doc.attr 'docfile').to eql input_file
      (expect doc.attr 'docdir').to eql (File.dirname input_file)
    end
  end

  describe '.reduce_file' do
    subject { described_class.method :reduce_file }

    it 'should reduce input when no options are specified' do
      run_scenario do
        input_source <<~'END'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]
        END
        reduce { subject.call input_file }
        expected_source 'primary content'
      end
    end
  end

  context ':to option' do
    it 'should reduce input to file at path specified by :to option' do
      with_tmp_file tmpdir: output_dir do |the_output_file|
        run_scenario do
          input_source the_input_source
          output_file the_output_file
          reduce { subject.reduce_file input_file, to: the_output_file.path }
          expected_source the_expected_source
        end
      end
    end

    it 'should reduce input to File object specified by :to option' do
      with_tmp_file tmpdir: output_dir do |the_output_file|
        run_scenario do
          input_source the_input_source
          output_file the_output_file
          reduce { subject.reduce_file input_file, to: the_output_file }
          expected_source the_expected_source
        end
      end
    end

    it 'should reduce input to file for Pathname object specified by :to option' do
      with_tmp_file tmpdir: output_dir do |the_output_file|
        run_scenario do
          input_source the_input_source
          output_file the_output_file
          reduce { subject.reduce_file input_file, to: (Pathname.new the_output_file.path) }
          expected_source the_expected_source
        end
      end
    end

    it 'should reduce input to string if :to option is String class' do
      run_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: String }
        expected_source the_expected_source
      end
    end

    it 'should reduce input and send to write method if :to option is StringIO object' do
      to = StringIO.new
      run_scenario do
        input_source the_input_source
        output_file to
        reduce { subject.reduce_file input_file, to: to }
        expected_source the_expected_source
      end
    end

    it 'should reduce input and send to write method if :to option value responds to write' do
      to = Class.new do
        attr_reader :string

        def initialize
          @string = nil
        end

        def write string
          @string = string
        end
      end.new
      run_scenario do
        input_source the_input_source
        output_file to
        reduce { subject.reduce_file input_file, to: to }
        expected_source the_expected_source
      end
    end

    it 'should reduce input but not write if :to option is /dev/null string' do
      run_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: '/dev/null' }
        expected_source the_expected_source
      end
    end

    it 'should reduce input but not write if :to option is nil' do
      run_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: nil }
        expected_source the_expected_source
      end
    end
  end

  context 'extension registry' do
    let :call_tracer_tree_processor do
      Class.new Asciidoctor::Extensions::TreeProcessor do
        attr_reader :calls

        def initialize *args
          super
          @calls = []
        end

        def process doc
          @calls << (doc.options[:reduced] == true)
          nil
        end
      end.new
    end

    let :register_extension_call_tracer do
      ext = call_tracer_tree_processor
      proc { prefer tree_processor ext }
    end

    let :extension_calls do
      call_tracer_tree_processor.calls
    end

    it 'should not register extension for call if extension is registered globally' do
      described_class::Extensions.register
      extensions = register_extension_call_tracer
      run_scenario do
        input_source the_input_source
        reduce_options sourcemap: true, extensions: extensions
        expected_source the_expected_source
      end
      (expect extension_calls).to eql [false, true]
    ensure
      described_class::Extensions.unregister
    end

    it 'should not register extension for call with custom extension registry if extension is registered globally' do
      described_class::Extensions.register
      extension_registry = Asciidoctor::Extensions.create(&register_extension_call_tracer)
      run_scenario do
        input_source the_input_source
        reduce_options sourcemap: true, extension_registry: extension_registry
        expected_source the_expected_source
      end
      (expect extension_calls).to eql [false, true]
      (expect extension_registry.groups[:reducer]).to be_nil
    ensure
      described_class::Extensions.unregister
    end

    it 'should not register extension for call to Asciidoctor load API if extension is registered globally' do
      described_class::Extensions.register
      extension_registry = Asciidoctor::Extensions.create(&register_extension_call_tracer)
      run_scenario do
        input_source the_input_source
        reduce_options safe: :safe, sourcemap: true, extension_registry: extension_registry
        reduce { Asciidoctor.load_file input_file, *reduce_options }
        expected_source the_expected_source
      end
      (expect extension_calls).to eql [false, true]
      (expect extension_registry.groups[:reducer]).to be_nil
    ensure
      described_class::Extensions.unregister
    end

    it 'should not register extensions in a custom extension registry again when reloading document' do
      extension_registry = Asciidoctor::Extensions.create(&register_extension_call_tracer)
      run_scenario do
        input_source the_input_source
        reduce_options sourcemap: true, extension_registry: extension_registry
        expected_source the_expected_source
      end
      (expect extension_calls).to eql [false, true]
      (expect extension_registry.groups[:reducer]).not_to be_nil
    end
  end
end
