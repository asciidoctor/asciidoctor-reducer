# frozen_string_literal: true

describe Asciidoctor::Reducer do
  let :the_input_source do
    <<~'END'
    before include

    include::multiple-paragraphs.adoc[]

    after include
    END
  end

  let :the_expected_source do
    <<~'END'
    before include

    first paragraph

    second paragraph
    with two lines

    after include
    END
  end

  context 'version' do
    it 'should provide VERSION constant' do
      (expect described_class::VERSION).to match %r/^\d+\.\d+\.\d+(\.\S+)?$/
    end
  end

  describe_method '.reduce' do
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

    it 'should reduce input when options are nil' do
      run_scenario do
        input_source <<~'END'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]
        END
        reduce { subject.call input_source, nil }
        expected_source 'primary content'
      end
    end

    it 'should reduce input when options are specified' do
      doc = run_scenario do
        input_source <<~'END'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]

        include::single-line-paragraph.adoc[]
        END
        reduce_options safe: :unsafe, sourcemap: true, attributes: { 'docdir' => fixtures_dir }
        reduce { subject.call input_source, reduce_options }
        expected_source <<~'END'
        primary content

        single-line paragraph
        END
      end
      (expect doc.options[:sourcemap]).to be true
      (expect doc.sourcemap).to be true
      (expect doc.options[:safe]).to be :unsafe
      (expect doc.safe).to be Asciidoctor::SafeMode::UNSAFE
      (expect doc.attr 'docdir').to eql fixtures_dir
    end

    it 'should set safe mode to :safe if not specified' do
      doc = run_scenario do
        input_source <<~'END'
        include::single-line-paragraph.adoc[]
        ifdef::flag[]
        conditional content
        endif::[]
        END
        reduce_options attributes: { 'docdir' => fixtures_dir }
        reduce { subject.call input_source, reduce_options }
        expected_source 'single-line paragraph'
      end
      (expect doc.options[:safe]).to eql :safe
      (expect doc.safe).to eql Asciidoctor::SafeMode::SAFE
    end

    it 'should reduce input specified as File object' do
      doc = (scenario = create_scenario do
        input_source the_input_source
        reduce { File.open(input_file, mode: 'rb:UTF-8') {|f| subject.call f } }
        expected_source the_expected_source
      end).run
      (expect doc.attr 'docname').to eql (scenario.input_file_basename '.adoc')
      (expect doc.attr 'docfile').to eql scenario.input_file
      (expect doc.attr 'docdir').to eql (File.dirname scenario.input_file)
    end
  end

  describe_method '.reduce_file' do
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

    it 'should reduce input when options are nil' do
      run_scenario do
        input_source <<~'END'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]
        END
        reduce { subject.call input_file, nil }
        expected_source 'primary content'
      end
    end

    it 'should reduce input when options are specified' do
      doc = run_scenario do
        input_source <<~'END'
        primary content
        ifdef::flag[]
        conditional content
        endif::[]

        include::single-line-paragraph.adoc[]
        END
        reduce_options safe: :unsafe, sourcemap: true
        reduce { subject.call input_file, reduce_options }
        expected_source <<~'END'
        primary content

        single-line paragraph
        END
      end
      (expect doc.options[:sourcemap]).to be true
      (expect doc.sourcemap).to be true
      (expect doc.options[:safe]).to be :unsafe
      (expect doc.safe).to be Asciidoctor::SafeMode::UNSAFE
      (expect doc.attr 'docdir').to eql fixtures_dir
    end

    it 'should set safe mode to :safe if not specified' do
      doc = run_scenario do
        input_source <<~'END'
        include::single-line-paragraph.adoc[]
        ifdef::flag[]
        conditional content
        endif::[]
        END
        reduce_options attributes: { 'flag' => '' }
        reduce { subject.call input_file, reduce_options }
        expected_source <<~'END'
        single-line paragraph
        conditional content
        END
      end
      (expect doc.options[:safe]).to eql :safe
      (expect doc.safe).to eql Asciidoctor::SafeMode::SAFE
    end

    it 'should convert CRLF newlines in input file to LF newlines in output file' do
      run_scenario do
        output_file create_output_file
        reduce_options to: output_file
        reduce { subject.call (create_file %w(main- .adoc), the_input_source, newline: :crlf), reduce_options }
        expected_source the_expected_source
      end
    end
  end

  context ':to option' do
    it 'should reduce input to file at path specified by :to option' do
      run_scenario do
        input_source the_input_source
        output_file create_output_file
        reduce_options to: output_file
        reduce { subject.reduce_file input_file, reduce_options }
        expected_source the_expected_source
      end
    end

    it 'should not modify newlines when writing output to file at path on Windows' do
      run_scenario do
        input_source the_input_source
        output_file create_output_file
        reduce_options to: output_file
        reduce do
          subject.reduce_file input_file, reduce_options
          (File.read output_file, mode: 'rb').chomp
        end
        expected_source the_expected_source
      end
    end

    it 'should not write newline to file if reduced result is empty' do
      run_scenario do
        input_source 'include::empty.adoc[]'
        output_file create_output_file
        reduce_options to: output_file
        reduce do
          subject.reduce_file input_file, reduce_options
          (File.read output_file, mode: 'rb').chomp
        end
        expected_source ''
      end
    end

    it 'should reduce input to managed File object specified by :to option' do
      with_tmp_file tmpdir: output_dir do |the_output_file|
        run_scenario do
          input_source the_input_source
          output_file the_output_file
          reduce_options to: the_output_file
          reduce { subject.reduce_file input_file, reduce_options }
          expected_source the_expected_source
        end
      end
    end

    it 'should reduce input to open File object specified by :to option' do
      run_scenario do
        input_source the_input_source
        output_file create_output_file
        reduce { File.open(output_file, mode: 'wb:UTF-8') {|f| subject.reduce_file input_file, to: f } }
        expected_source the_expected_source
      end
    end

    it 'should fail to reduce file if File object specified by :to option is closed' do
      expect do
        run_scenario do
          input_source the_input_source
          output_file create_output_file
          reduce { File.open(output_file, mode: 'wb:UTF-8') {|f| subject.reduce_file input_file, to: f.tap(&:close) } }
        end
      end.to raise_exception IOError, 'closed stream'
    end

    it 'should reduce input to file for Pathname object specified by :to option' do
      run_scenario do
        input_source the_input_source
        output_file create_output_file
        reduce_options to: (Pathname.new output_file)
        reduce { subject.reduce_file input_file, reduce_options }
        expected_source the_expected_source
      end
    end

    it 'should reduce input to string if :to option is String class' do
      run_scenario do
        input_source the_input_source
        reduce_options to: String
        reduce { subject.reduce_file input_file, reduce_options }
        expected_source the_expected_source
      end
    end

    it 'should reduce input and send to write method if :to option is StringIO object' do
      run_scenario do
        input_source the_input_source
        output_file (to = StringIO.new)
        reduce_options to: to
        reduce { subject.reduce_file input_file, reduce_options }
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
        reduce_options to: to
        reduce { subject.reduce_file input_file, reduce_options }
        expected_source the_expected_source
      end
    end

    it 'should reduce input but not write if :to option is /dev/null string' do
      run_scenario do
        input_source the_input_source
        reduce_options to: '/dev/null'
        reduce { subject.reduce_file input_file, reduce_options }
        expected_source the_expected_source
      end
    end

    it 'should reduce input but not write if :to option is nil' do
      run_scenario do
        input_source the_input_source
        reduce_options to: nil
        reduce { subject.reduce_file input_file, reduce_options }
        expected_source the_expected_source
      end
    end

    it 'should allow :to option to be used with reduce method' do
      run_scenario do
        output_file create_output_file
        reduce_options to: output_file, attributes: { 'docdir' => fixtures_dir }
        reduce { subject.reduce the_input_source, reduce_options }
        expected_source the_expected_source
      end
    end

    it 'should not pass :to option to Asciidoctor.load_file' do
      doc = run_scenario do
        input_source the_input_source
        output_file create_output_file
        reduce_options to: output_file
        reduce { subject.reduce_file input_file, reduce_options }
        expected_source the_expected_source
      end
      (expect doc.options).not_to have_key :to
    end

    it 'should not pass :to option to Asciidoctor.load' do
      doc = run_scenario do
        input_source the_input_source
        output_file create_output_file
        reduce_options to: output_file, attributes: { 'docdir' => fixtures_dir }
        reduce { subject.reduce input_source, reduce_options }
        expected_source the_expected_source
      end
      (expect doc.options).not_to have_key :to
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

    context 'when registered globally' do
      before { described_class::Extensions.register }

      after { described_class::Extensions.unregister }

      it 'should not register extension for call' do
        extensions = register_extension_call_tracer
        run_scenario do
          input_source the_input_source
          reduce_options sourcemap: true, extensions: extensions
          expected_source the_expected_source
        end
        (expect extension_calls).to eql [false, true]
      end

      it 'should not pass :extension_registry option with nil value' do
        doc = run_scenario do
          input_source the_input_source
          expected_source the_expected_source
        end
        (expect doc.options).not_to have_key :extension_registry
      end

      it 'should not register extension for call with custom extension registry' do
        extension_registry = Asciidoctor::Extensions.create(&register_extension_call_tracer)
        run_scenario do
          input_source the_input_source
          reduce_options sourcemap: true, extension_registry: extension_registry
          expected_source the_expected_source
        end
        (expect extension_calls).to eql [false, true]
        (expect extension_registry.groups[:reducer]).to be_nil
      end

      it 'should not register extension for call to Asciidoctor.load_file' do
        extension_registry = Asciidoctor::Extensions.create(&register_extension_call_tracer)
        run_scenario do
          input_source the_input_source
          reduce_options safe: :safe, sourcemap: true, extension_registry: extension_registry
          reduce { Asciidoctor.load_file input_file, reduce_options }
          expected_source the_expected_source
        end
        (expect extension_calls).to eql [false, true]
        (expect extension_registry.groups[:reducer]).to be_nil
      end
    end
  end
end
