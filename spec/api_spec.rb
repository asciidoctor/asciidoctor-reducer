# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::Reducer do
  it 'should provide VERSION constant' do
    (expect described_class::VERSION).to match %r/^\d+\.\d+\.\d+(\.\S+)?$/
  end

  let :the_input_source do
    <<~'EOS'
    before include

    include::single-line-paragraph.adoc[]

    after include
    EOS
  end

  let :the_expected_source do
    <<~'EOS'
    before include

    single line paragraph

    after include
    EOS
  end

  describe '.reduce' do
    subject { described_class.method :reduce }

    it 'should reduce input when no options are specified' do
      scenario = create_scenario do
        input_source <<~'EOS'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]
        EOS
        reduce { subject.call input_source }
        expected_source 'primary content'
      end
      (expect scenario.doc).to have_source scenario.expected_source
    end

    it 'should reduce input specified as File object' do
      scenario, doc = create_scenario do
        input_source the_input_source
        reduce { File.open(input_file, mode: 'r:UTF-8') {|f| subject.call f } }
        expected_source the_expected_source
      end
      (expect doc).to have_source scenario.expected_source
      input_file = scenario.input_file
      (expect doc.attr 'docname').to eql (File.basename input_file, '.adoc')
      (expect doc.attr 'docfile').to eql input_file
      (expect doc.attr 'docdir').to eql (File.dirname input_file)
    end
  end

  describe '.reduce_file' do
    subject { described_class.method :reduce_file }

    it 'should reduce input when no options are specified' do
      scenario, doc = create_scenario do
        input_source <<~'EOS'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]
        EOS
        reduce { subject.call input_file }
        expected_source 'primary content'
      end
      (expect doc).to have_source scenario.expected_source
    end
  end

  describe '#write' do
    it 'should reduce input to file at path specified by :to option' do
      with_tmp_file tmpdir: output_dir do |the_output_file|
        scenario = create_scenario do
          input_source the_input_source
          reduce { subject.reduce_file input_file, to: the_output_file.path }
          expected_source the_expected_source
        end

        (expect the_output_file.read.chomp).to eql scenario.expected_source
      end
    end

    it 'should reduce input to file for Pathname specified by :to option' do
      with_tmp_file tmpdir: output_dir do |the_output_file|
        scenario = create_scenario do
          input_source the_input_source
          reduce { subject.reduce_file input_file, to: (Pathname.new the_output_file.path) }
          expected_source the_expected_source
        end

        (expect the_output_file.read.chomp).to eql scenario.expected_source
      end
    end

    it 'should reduce input to string if :to option is String' do
      scenario, result = create_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: String }
        expected_source the_expected_source
      end
      (expect result).to eql scenario.expected_source
    end

    it 'should reduce input and send to write method if :to option is IO' do
      to = StringIO.new
      scenario = create_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: to }
        expected_source the_expected_source
      end

      (expect to.string).to eql (scenario.expected_source + ?\n)
    end

    it 'should reduce input and send to write method if :to option value responds to write' do
      to = (Class.new do
        attr_reader :string

        def initialize
          @string = nil
        end

        def write string
          @string = string
        end
      end).new
      scenario = create_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: to }
        expected_source the_expected_source
      end
      (expect to.string).to eql (scenario.expected_source + ?\n)
    end

    it 'should reduce input but not write if :to option is /dev/null' do
      scenario, doc = create_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: '/dev/null' }
        expected_source the_expected_source
      end
      (expect doc).to have_source scenario.expected_source
    end

    it 'should reduce input but not write if :to option is nil' do
      scenario, doc = create_scenario do
        input_source the_input_source
        reduce { subject.reduce_file input_file, to: nil }
        expected_source the_expected_source
      end
      (expect doc).to have_source scenario.expected_source
    end
  end

  describe 'extension registry' do
    let :call_tracer_tree_processor do
      (Class.new Asciidoctor::Extensions::TreeProcessor do
        attr_reader :calls

        def initialize *args
          super
          @calls = []
        end

        def process doc
          @calls << (doc.options[:reduced] == true)
          nil
        end
      end).new
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
      result = subject.reduce_file (fixture_file 'parent-with-single-include.adoc'), sourcemap: true,
        extensions: register_extension_call_tracer
      expected_lines = <<~'EOS'.chomp.split ?\n
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
      (expect extension_calls).to eql [false, true]
      (expect result.source_lines).to eql expected_lines
    ensure
      described_class::Extensions.unregister
    end

    it 'should not register extension for call with custom extension registry if extension is registered globally' do
      described_class::Extensions.register
      ext_reg = Asciidoctor::Extensions.create(&register_extension_call_tracer)
      result = subject.reduce_file (fixture_file 'parent-with-single-include.adoc'), extension_registry: ext_reg,
        sourcemap: true
      expected_lines = <<~'EOS'.chomp.split ?\n
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
      (expect result.source_lines).to eql expected_lines
      (expect ext_reg.groups[:reducer]).to be_nil
      (expect extension_calls).to eql [false, true]
    ensure
      described_class::Extensions.unregister
    end

    it 'should not register extension for call to load API if extension is registered globally' do
      described_class::Extensions.register
      ext_reg = Asciidoctor::Extensions.create(&register_extension_call_tracer)
      result = Asciidoctor.load_file (fixture_file 'parent-with-single-include.adoc'), extension_registry: ext_reg,
        sourcemap: true, safe: :safe
      expected_lines = <<~'EOS'.chomp.split ?\n
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
      (expect result.source_lines).to eql expected_lines
      (expect ext_reg.groups[:reducer]).to be_nil
      (expect extension_calls).to eql [false, true]
    ensure
      described_class::Extensions.unregister
    end

    it 'should not register extensions in a custom extension registry twice when reloading document' do
      ext_reg = Asciidoctor::Extensions.create(&register_extension_call_tracer)
      result = subject.reduce_file (fixture_file 'parent-with-single-include.adoc'), extension_registry: ext_reg,
        sourcemap: true
      expected_lines = <<~'EOS'.chomp.split ?\n
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
      (expect result.source_lines).to eql expected_lines
      (expect ext_reg.groups[:reducer]).not_to be_nil
      (expect extension_calls).to eql [false, true]
    end
  end
end
