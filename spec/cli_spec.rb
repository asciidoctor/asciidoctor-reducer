# frozen_string_literal: true

describe Asciidoctor::Reducer::Cli do
  before do
    @old_stdin, $stdin = $stdin, StringIO.new
    @old_stdout, $stdout = $stdout, StringIO.new # rubocop:disable RSpec/ExpectOutput
    @old_stderr, $stderr = $stderr, StringIO.new # rubocop:disable RSpec/ExpectOutput
  end

  after do
    $stdin, $stdout, $stderr = @old_stdin, @old_stdout, @old_stderr # rubocop:disable RSpec/InstanceVariable,RSpec/ExpectOutput
  end

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

  context 'bin script' do
    it 'should install bin script named asciidoctor-reducer' do
      bin_script = (Pathname.new Gem.bindir) / 'asciidoctor-reducer'
      bin_script = Pathname.new Gem.bin_path 'asciidoctor-reducer', 'asciidoctor-reducer' unless bin_script.exist?
      (expect bin_script).to exist
    end

    it 'should read args from ARGV by default' do
      out, _, res = run_command asciidoctor_reducer_bin, '-v'
      (expect res.exitstatus).to eql 0
      (expect out.chomp).to eql %(asciidoctor-reducer #{Asciidoctor::Reducer::VERSION})
    end

    it 'should convert a document at the specified relative path' do
      out, _, res = run_command asciidoctor_reducer_bin, (fixture_file 'book.adoc', relative: true)
      (expect res.exitstatus).to eql 0
      expected_source = <<~'END'.chomp
      = Book Title

      == Chapter One

      content

      [appendix]
      == Installation

      content
      END

      (expect out.chomp).to eql expected_source
    end

    it 'should convert a document at the specified absolute path' do
      out, _, res = run_command asciidoctor_reducer_bin, (fixture_file 'book.adoc')
      (expect res.exitstatus).to eql 0
      expected_source = <<~'END'.chomp
      = Book Title

      == Chapter One

      content

      [appendix]
      == Installation

      content
      END

      (expect out.chomp).to eql expected_source
    end
  end

  context 'signals', unless: windows? do
    it 'should handle HUP signal gracefully' do
      signal = 'signal=HUP'
      out, err, res = run_scenario do
        input_source the_input_source
        reduce { run_command asciidoctor_reducer_bin, '-r', (fixture_file 'send_signal.rb'), input_file, '-a', signal }
      end

      (expect res.exitstatus).to (be 1).or (be 129)
      (expect out).to be_empty
      (expect err).to be_empty
    end

    it 'should handle INT signal gracefully and append line feed' do
      signal = 'signal=INT'
      out, err, res = run_scenario do
        input_source the_input_source
        reduce { run_command asciidoctor_reducer_bin, '-r', (fixture_file 'send_signal.rb'), input_file, '-a', signal }
      end

      (expect res.exitstatus).to (be 2).or (be 130)
      (expect out).to be_empty
      if jruby?
        (expect err).to be_empty
      else
        (expect err).to eql $/
      end
    end

    it 'should handle KILL signal gracefully' do
      signal = 'signal=KILL'
      out, err, res = run_scenario do
        input_source the_input_source
        reduce { run_command asciidoctor_reducer_bin, '-r', (fixture_file 'send_signal.rb'), input_file, '-a', signal }
      end

      (expect res.exitstatus).to be_nil
      (expect res.success?).to be_falsey
      (expect res.termsig).to eql 9
      (expect out).to be_empty
      (expect err).to be_empty
    end
  end

  context 'options' do
    it 'should display error message and return non-zero exit status when invalid option is specified' do
      (expect subject.run %w(--invalid)).to eql 1
      (expect $stderr.string.chomp).to eql 'asciidoctor-reducer: invalid option: --invalid'
      (expect $stdout.string).to start_with 'Usage: asciidoctor-reducer '
    end

    it 'should display program name and version when -v option is specified' do
      (expect subject.run %w(-v)).to eql 0
      (expect $stdout.string.chomp).to eql %(asciidoctor-reducer #{Asciidoctor::Reducer::VERSION})
    end

    it 'should ignore other options when -v option is specified' do
      (expect subject.run %w(-v -h)).to eql 0
      (expect $stdout.string.chomp).to eql %(asciidoctor-reducer #{Asciidoctor::Reducer::VERSION})
    end

    it 'should display help text when -h option is specified' do
      (expect subject.run %w(-h)).to eql 0
      stdout = $stdout.string
      (expect stdout).to start_with 'Usage: asciidoctor-reducer '
      (expect stdout).to include 'Reduces a composite AsciiDoc document'
      (expect stdout).to include '-h, --help'
    end

    it 'should write output to file specified by the -o option' do
      run_scenario do
        input_source the_input_source
        output_file create_output_file
        reduce { subject.run ['-o', output_file, input_file] }
        expected_source the_expected_source
      end
    end

    it 'should create empty file specified by -o option if output is empty' do
      run_scenario do
        input_source 'include::empty.adoc[]'
        output_file create_output_file
        reduce { subject.run ['-o', output_file, input_file] }
        expected_source ''
      end
    end

    it 'should write to stdout when -o option is -' do
      run_scenario do
        input_source the_input_source
        output_file $stdout
        reduce { subject.run [input_file, '-o', '-'] }
        expected_source the_expected_source
      end
    end

    it 'should exit with status code 1 when value of -o option is a directory' do
      run_scenario do
        input_source the_input_source
        output_file $stdout
        reduce { subject.run [input_file, '-o', Dir.tmpdir] }
        expected_exit_status 1
        expected_source ''
      end

      if (message = $stderr.string.downcase).include? 'permission'
        (expect message).to include 'permission denied'
      else
        (expect message).to include 'is a directory'
      end
    end

    it 'should allow runtime attribute to be specified using -a option' do
      run_scenario do
        input_source <<~'END'
        = Book Title

        include::{chaptersdir}/ch1.adoc[]
        END

        output_file $stdout
        reduce { subject.run [input_file, '-a', 'chaptersdir=chapters', '-a', 'doctitle=Untitled'] }
        expected_source <<~'END'
        = Book Title

        == Chapter One

        content
        END
      end
    end

    it 'should set attribute value to empty string if only name is passed to -a option' do
      run_scenario do
        input_source <<~'END'
        primary content
        ifdef::flag[]
        ifeval::["{flag}" == ""]
        conditional content
        endif::[]
        endif::flag[]
        END

        output_file $stdout
        reduce { subject.run [input_file, '-a', 'flag'] }
        expected_source <<~'END'
        primary content
        conditional content
        END
      end
    end

    it 'should reduce preprocessor conditionals by default' do
      run_scenario do
        input_source 'ifdef::asciidoctor-version[text]'
        output_file $stdout
        reduce { subject.run [input_file] }
        expected_source 'text'
      end
    end

    it 'should preserve preprocessor conditionals if --preserve-conditionals option is specified' do
      run_scenario do
        input_source 'ifdef::asciidoctor-version[text]'
        output_file $stdout
        reduce { subject.run [input_file, '--preserve-conditionals'] }
        expected_source input_source
      end
    end

    it 'should set level on logger to higher value specified by --log-level option' do
      run_scenario do
        input_source <<~'END'
        before include

        include::no-such-file.adoc[]

        after include
        END

        output_file $stdout
        reduce { subject.run [input_file, '--log-level', 'fatal'] }
        expected_source <<~END
        before include

        Unresolved directive in #{input_file_basename} - include::no-such-file.adoc[]

        after include
        END
      end

      (expect $stderr.string.chomp).to be_empty
    end

    it 'should ignore --log-level option if value is warn' do
      run_scenario do
        input_source <<~'END'
        before include

        include::no-such-file.adoc[opts=optional]

        after include
        END

        output_file $stdout
        reduce { subject.run [input_file, '--log-level', 'warn'] }
        expected_source <<~'END'
        before include


        after include
        END
      end

      (expect $stderr.string.chomp).to be_empty
    end

    it 'should set level on logger to lower value specified by --log-level option' do
      run_scenario do
        input_source <<~'END'
        before include

        include::no-such-file.adoc[opts=optional]

        after include
        END

        output_file $stdout
        reduce { subject.run [input_file, '--log-level', 'info'] }
        expected_source <<~'END'
        before include


        after include
        END
      end

      (expect $stderr.string).to include 'optional include dropped'
    end

    it 'should suppress log messages when -q option is specified' do
      run_scenario do
        input_source <<~'END'
        before include

        include::no-such-file.adoc[]

        after include
        END

        output_file $stdout
        reduce { subject.run [input_file, '-q'] }
        expected_source <<~END
        before include

        Unresolved directive in #{input_file_basename} - include::no-such-file.adoc[]

        after include
        END
      end

      (expect $stderr.string.chomp).to be_empty
    end

    it 'should require library specified by -r option' do
      run_scenario do
        input_source the_input_source
        the_ext_file = create_extension_file %(puts 'extension required'\n)
        output_file $stdout
        reduce { subject.run [input_file, '-r', the_ext_file] }
        expected_source <<~END
        extension required
        #{the_expected_source.chomp}
        END
      end
    end

    it 'should require libraries specified by single -r option' do
      run_scenario do
        input_source the_input_source
        a_ext_file = create_extension_file %(puts 'extension required'\n)
        b_ext_file = create_extension_file %(puts 'another extension required'\n)
        output_file $stdout
        reduce { subject.run [input_file, '-r', ([a_ext_file, b_ext_file].join ',')] }
        expected_source <<~END
        extension required
        another extension required
        #{the_expected_source.chomp}
        END
      end
    end

    it 'should require libraries specified by multiple -r options' do
      run_scenario do
        input_source the_input_source
        a_ext_file = create_extension_file %(puts 'extension required'\n)
        b_ext_file = create_extension_file %(puts 'another extension required'\n)
        output_file $stdout
        reduce { subject.run [input_file, '-r', a_ext_file, '-r', b_ext_file] }
        expected_source <<~END
        extension required
        another extension required
        #{the_expected_source.chomp}
        END
      end
    end

    it 'should show error message if library specified by -r cannot be required' do
      expected_message = %(asciidoctor-reducer: 'no-such-library' could not be required)
      run_scenario do
        input_source the_input_source
        output_file $stdout
        reduce { subject.run [input_file, '-r', 'no-such-library'] }
        expected_exit_status 1
        verify (proc do |delegate, exit_status|
          delegate.call exit_status
          (expect $stderr.string).to start_with expected_message
          (expect $stdout.string).to be_empty
        end)
      end
    end
  end

  context 'arguments' do
    it 'should show error message and usage and return non-zero exit status when no arguments are given' do
      expected = 'asciidoctor-reducer: Please specify an AsciiDoc file to reduce.'
      (expect subject.run []).to eql 1
      (expect $stderr.string.chomp).to eql expected
      (expect $stdout.string).to start_with 'Usage: asciidoctor-reducer '
    end

    it 'should show error message and usage and return non-zero exit status when more than one argument is given' do
      expected = 'asciidoctor-reducer: extra arguments detected (unparsed arguments: bar.adoc)'
      (expect subject.run %w(foo.adoc bar.adoc)).to eql 1
      (expect $stderr.string.chomp).to eql expected
      (expect $stdout.string).to start_with 'Usage: asciidoctor-reducer '
    end

    it 'should write to stdout when -o option is not specified' do
      run_scenario do
        input_source the_input_source
        output_file $stdout
        reduce { subject.run [input_file] }
        expected_source the_expected_source
      end
    end

    it 'should read from stdin when argument is -' do
      run_scenario do
        $stdin.string = <<~END
        before include

        include::#{fixture_file 'multiple-paragraphs.adoc'}[]

        after include
        END

        output_file $stdout
        reduce { subject.run %w(-) }
        expected_source the_expected_source
      end
    end
  end

  context 'safe mode' do
    it 'should permit file to be included in parent directory of docdir using relative path' do
      run_scenario do
        input_file create_input_file <<~'END', subdir: 'subdir'
        before include

        include::../multiple-paragraphs.adoc[]

        after include
        END

        output_file $stdout
        reduce { subject.run [input_file] }
        expected_source the_expected_source
      end
    end

    it 'should permit file to be included in parent directory of docdir using absolute path' do
      run_scenario do
        input_file create_input_file <<~END, subdir: 'subdir'
        before include

        include::#{fixture_file 'multiple-paragraphs.adoc'}[]

        after include
        END

        output_file $stdout
        reduce { subject.run [input_file] }
        expected_source the_expected_source
      end
    end

    it 'should not permit file to be included in parent directory of docdir when safe mode is safe' do
      run_scenario do
        input_file create_input_file <<~'END', subdir: 'subdir'
        before include

        include::../multiple-paragraphs.adoc[]

        after include
        END

        output_file $stdout
        reduce { subject.run [input_file, '-S', 'safe'] }
        expected_source <<~END
        before include

        Unresolved directive in #{input_file_basename} - include::../multiple-paragraphs.adoc[]

        after include
        END
      end

      (expect $stderr.string).to include 'illegal reference to ancestor of jail'
    end
  end

  context 'error' do
    it 'should suggest --trace option if application ends in error' do
      run_scenario do
        input_source the_input_source
        the_ext_file = create_extension_file 'Asciidoctor::Extensions.register { tree_processor {} }'
        reduce { subject.run [input_file, '-r', the_ext_file] }
        expected_exit_status 1
        verify (proc do |delegate, exit_status|
          delegate.call exit_status
          stderr_lines = $stderr.string.chomp.lines
          (expect stderr_lines[0]).to include 'asciidoctor-reducer: FAILED: '
          (expect stderr_lines[0]).to include 'No block specified to process tree processor extension'
          (expect stderr_lines[-1]).to include 'Use --trace to show backtrace'
          (expect $stdout.string).to be_empty
        end)
        finally { Asciidoctor::Extensions.unregister_all }
      end
    end

    it 'should show backtrace of error if --trace option is specifed' do
      run_scenario do
        input_source the_input_source
        the_ext_file = create_extension_file 'Asciidoctor::Extensions.register { tree_processor {} }'
        reduce do
          expect do
            subject.run [input_file, '-r', the_ext_file, '--trace']
          end.to raise_exception ArgumentError, %r/No block specified to process tree processor extension/
        end
        finally { Asciidoctor::Extensions.unregister_all }
      end
    end
  end
end
