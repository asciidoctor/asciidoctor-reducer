# frozen_string_literal: true

describe Asciidoctor::Reducer do
  it 'should be able to require library from Ruby process' do
    # NOTE asciidoctor/reducer/version will already be required by Bundler
    script_file = fixture_file 'print_version.rb'
    output = %x(#{ruby} #{Shellwords.escape script_file}).lines.map(&:chomp)
    (expect output).to eql [described_class::VERSION, 'loaded']
  end

  it 'should register extensions globally when asciidoctor/reducer is required' do
    unrequire 'asciidoctor/reducer'
    (expect require 'asciidoctor/reducer').not_to be_nil
    (expect Asciidoctor::Extensions.groups).to have_key described_class::Extensions.key
  ensure
    described_class::Extensions.unregister
  end

  it 'should be able to require library using the alias asciidoctor-reducer' do
    unrequire 'asciidoctor/reducer'
    (expect require 'asciidoctor-reducer').not_to be_nil
    (expect Asciidoctor::Extensions.groups).to have_key described_class::Extensions.key
  ensure
    described_class::Extensions.unregister
  end

  it 'should load document with no includes' do
    run_scenario do
      input_source <<~'END'
      no includes to be found here

      not a single one
      END

      reduce_options sourcemap: true
      expected_source input_source
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.options[:reduced]).to be_falsy
        (expect doc.blocks).to have_size 2
        (expect doc.sourcemap).to be true
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
        (expect doc.attr 'docname').to eql (input_file_basename '.adoc')
        (expect doc.attr 'docfile').to eql input_file
        (expect doc.attr 'docdir').to eql (File.dirname input_file)
      end)
    end
  end

  it 'should not enable sourcemap on document with no includes' do
    run_scenario do
      input_source <<~'END'
      no includes to be found here

      not a single one
      END

      expected_source input_source
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.options[:reduced]).to be_falsy
        (expect doc.sourcemap).to be_falsy
        (expect doc.blocks[0].source_location).to be_nil
      end)
    end
  end

  it 'should resolve top-level include with no nested includes in input file' do
    run_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      no includes here

      just regular paragraph text

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.options[:reduced]).to be true
        (expect doc.blocks).to have_size 4
        (expect doc.sourcemap).to be true
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
        (expect (doc.blocks.map {|it| it.file }).uniq).to eql [input_file]
        (expect doc.attr 'docname').to eql (input_file_basename '.adoc')
        (expect doc.attr 'docfile').to eql input_file
        (expect doc.attr 'docdir').to eql (File.dirname input_file)
        (expect doc.catalog[:includes]['no-includes']).to be true
      end)
    end
  end

  it 'should resolve top-level include with no nested includes in input string' do
    run_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END

      chdir fixtures_dir
      reduce_options sourcemap: true
      reduce { described_class.reduce input_source, **reduce_options }
      expected_source <<~'END'
      before include

      no includes here

      just regular paragraph text

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.options[:reduced]).to be true
        (expect doc.blocks).to have_size 4
        (expect doc.sourcemap).to be true
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
        (expect (doc.blocks.map {|it| it.file }).uniq).to eql [nil]
        (expect (doc.blocks.map {|it| it.source_location.path }).uniq).to eql ['<stdin>']
        (expect doc.attr 'docname').to be_nil
        (expect doc.attr 'docfile').to be_nil
        (expect doc.attr 'docdir').to eql fixtures_dir
        (expect doc.catalog[:includes]['no-includes']).to be true
      end)
    end
  end

  it 'should not enable sourcemap on reduced document' do
    run_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      no includes here

      just regular paragraph text

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.options[:reduced]).to be_falsy
        (expect doc.sourcemap).to be_falsy
        (expect doc.blocks[0].source_location).to be_nil
      end)
    end
  end

  it 'should not reload document with includes if sourcemap is not enabled' do
    docs = []
    run_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END

      reduce_options extensions: (proc do
        tree_processor do
          prefer
          process do |doc|
            docs << doc
            nil
          end
        end
      end)

      expected_source <<~'END'
      before include

      no includes here

      just regular paragraph text

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect docs).to have_size 1
        (expect docs[0].object_id).to eql doc.object_id
        (expect doc.catalog[:includes]['no-includes']).to be true
      end)
    end
  end

  it 'should resolve top-level relative include with nested include' do
    run_scenario do
      include_source <<~'END'
      before nested include

      include::no-includes.adoc[]

      after nested include
      END

      input_source <<~END
      before include

      include::#{include_file_basename}[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      before nested include

      no includes here

      just regular paragraph text

      after nested include

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 6
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
        (expect (doc.blocks.map {|it| it.file }).uniq).to eql [input_file]
      end)
    end
  end

  it 'should resolve top-level absolute include with nested include' do
    run_scenario do
      include_source <<~'END'
      before nested include

      include::no-includes.adoc[]

      after nested include
      END

      input_source <<~END
      before include

      include::#{include_file}[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      before nested include

      no includes here

      just regular paragraph text

      after nested include

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 6
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
        (expect (doc.blocks.map {|it| it.file }).uniq).to eql [input_file]
      end)
    end
  end

  it 'should resolve nested include relative to include file' do
    run_scenario do
      include_source <<~END
      before relative include

      include::#{File.basename (create_include_file 'contents of relative include', subdir: 'subdir')}[]

      after relative include
      END

      input_source <<~END
      before include

      include::subdir/#{File.basename (include_file subdir: 'subdir')}[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      before relative include

      contents of relative include

      after relative include

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 5
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
      end)
    end
  end

  it 'should resolve include with single-line paragraph' do
    run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      single-line paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should skip escaped include' do
    run_scenario do
      input_source <<~'END'
      before include

      \include::not-processed.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source input_source
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should resolve include at start of document' do
    run_scenario do
      input_source <<~'END'
      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      single-line paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 2
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
      end)
    end
  end

  it 'should resolve include at end of document' do
    run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      single-line paragraph
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 2
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
      end)
    end
  end

  it 'should resolve include with multiline paragraph' do
    run_scenario do
      include_source <<~'END'
      first line
      second line
      third line
      END

      input_source <<~END
      before include

      include::#{include_file_basename}[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      first line
      second line
      third line

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 7]
      end)
    end
  end

  it 'should resolve include with multiple paragraphs' do
    run_scenario do
      input_source <<~'END'
      before include

      include::multiple-paragraphs.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      first paragraph

      second paragraph
      with two lines

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8]
      end)
    end
  end

  it 'should resolve adjacent includes' do
    run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]
      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      single-line paragraph
      single-line paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
      end)
    end
  end

  it 'should resolve include that follows include with nested include' do
    run_scenario do
      include_source <<~'END'
      before nested include

      include::no-includes.adoc[]

      after nested include
      END

      input_source <<~END
      before

      include::#{include_file_basename}[]

      then

      include::no-includes.adoc[]

      after
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before

      before nested include

      no includes here

      just regular paragraph text

      after nested include

      then

      no includes here

      just regular paragraph text

      after
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 9
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11, 13, 15, 17]
      end)
    end
  end

  it 'should assign same line number to preamble and its paragraph' do
    run_scenario do
      input_source <<~'END'
      = Document Title

      include::single-line-paragraph.adoc[]

      == Chapter A

      == Chapter B
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      = Document Title

      single-line paragraph

      == Chapter A

      == Chapter B
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by {|it| it.context != :document }
        (expect blocks).to have_size 5
        (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 3, 5, 7]
      end)
    end
  end

  it 'should flag top-level include that cannot be resolved as an unresolved directive' do
    run_scenario do
      input_source <<~'END'
      before include

      include::no-such-file.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~END
      before include

      Unresolved directive in #{input_file_basename} - include::no-such-file.adoc[]

      after include
      END

      expected_log_messages [{ severity: :ERROR, message: '~include file not found:', last: true }]
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect doc.blocks[1].source).to start_with 'Unresolved directive'
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should resolve include that follows unresolved include' do
    run_scenario do
      input_source <<~'END'
      before includes

      include::no-such-file.adoc[]

      between includes

      include::single-line-paragraph.adoc[]

      after includes
      END

      reduce_options sourcemap: true
      expected_source <<~END
      before includes

      Unresolved directive in #{input_file_basename} - include::no-such-file.adoc[]

      between includes

      single-line paragraph

      after includes
      END

      expected_log_messages [{ severity: :ERROR, message: '~include file not found:', last: true }]
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 5
        (expect doc.blocks[1].source).to start_with 'Unresolved directive'
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
      end)
    end
  end

  it 'should resolve include directly adjacent to unresolved include' do
    run_scenario do
      input_source <<~'END'
      before includes

      include::no-such-file.adoc[]
      include::single-line-paragraph.adoc[]

      after includes
      END

      reduce_options sourcemap: true
      expected_source <<~END
      before includes

      Unresolved directive in #{input_file_basename} - include::no-such-file.adoc[]
      single-line paragraph

      after includes
      END

      expected_log_messages [{ severity: :ERROR, message: '~include file not found:', last: true }]
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect doc.blocks[1].source).to start_with 'Unresolved directive'
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
      end)
    end
  end

  it 'should resolve include after unresolved optional include' do
    run_scenario do
      input_source <<~'END'
      before includes

      include::no-such-file.adoc[opts=optional]

      between includes

      include::single-line-paragraph.adoc[]

      after includes
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before includes


      between includes

      single-line paragraph

      after includes
      END

      expected_log_messages [{ severity: :INFO, message: '~optional include dropped', last: true }],
        using_log_level: :INFO
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4, 6, 8]
      end)
    end
  end

  it 'should skip optional top-level include that cannot be resolved' do
    run_scenario do
      input_source <<~'END'
      before include

      include::no-such-file.adoc[opts=optional]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include


      after include
      END

      expected_log_messages [{ severity: :INFO, message: '~optional include dropped', last: true }],
        using_log_level: :INFO
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 2
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
      end)
    end
  end

  it 'should flag nested include that cannot be resolved as an unresolved directive' do
    run_scenario do
      include_source <<~'END'
      before include

      include::no-such-file.adoc[]

      after include
      END

      input_source <<~END
      before top-level include

      include::#{include_file_basename}[]

      after top-level include
      END

      reduce_options sourcemap: true
      expected_source <<~END
      before top-level include

      before include

      Unresolved directive in #{include_file_basename} - include::no-such-file.adoc[]

      after include

      after top-level include
      END

      expected_log_messages [{ severity: :ERROR, message: '~include file not found:', last: true }]
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 5
        (expect doc.blocks[2].source).to start_with 'Unresolved directive'
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
      end)
    end
  end

  it 'should flag include as an unresolved directive if target is empty' do
    run_scenario do
      input_source <<~'END'
      before include

      include::{empty}[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~END
      before include

      Unresolved directive in #{input_file_basename} - include::{empty}[]

      after include
      END

      expected_log_messages [
        { severity: :WARN, message: '~include dropped because resolved target is blank:', last: true },
      ]
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should reduce includes when safe mode is server' do
    run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options safe: :server, sourcemap: true
      expected_source <<~'END'
      before include

      single-line paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.attr 'docname').to eql (input_file_basename '.adoc')
        (expect doc.attr 'docfile').to eql input_file_basename
        (expect doc.attr 'docdir').to be_empty
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should replace includes with links if safe mode is secure' do
    run_scenario do
      input_source <<~'END'
      before includes

      include::single-line-paragraph.adoc[]

      include::multiple-paragraphs.adoc[]

      after includes
      END

      reduce_options safe: :secure, sourcemap: true
      expected_source <<~'END'
      before includes

      link:single-line-paragraph.adoc[role=include]

      link:multiple-paragraphs.adoc[role=include]

      after includes
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
      end)
    end
  end

  it 'should replace include with link if target is URL and allow-uri-read is not set' do
    run_scenario do
      input_source <<~'END'
      before include

      include::https://example.org/intro.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      link:https://example.org/intro.adoc[role=include]

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should reduce remote include if allow-uri-read is set' do
    with_local_webserver do |base_url|
      run_scenario do
        input_source <<~END
        before include

        include::#{base_url}/no-includes.adoc[]

        after include
        END

        reduce_options attributes: 'allow-uri-read'
        expected_source <<~'END'
        before include

        no includes here

        just regular paragraph text

        after include
        END
      end
    end
  end

  it 'should reduce remote include with include if allow-uri-read is set' do
    with_local_webserver do |base_url|
      run_scenario do
        include_source <<~'END'
        before nested include

        include::no-includes.adoc[]

        after nested include
        END

        input_source <<~END
        before include

        include::#{base_url}/#{include_file_basename}[]

        after include
        END

        reduce_options attributes: 'allow-uri-read'
        expected_source <<~'END'
        before include

        before nested include

        no includes here

        just regular paragraph text

        after nested include

        after include
        END
      end
    end
  end

  it 'should not process link macro following include skipped by include processor when safe mode is not secure' do
    run_scenario do
      input_source <<~'END'
      before includes

      include::ignored.adoc[]
      link:foobar.adoc[]

      after includes
      END

      reduce_options sourcemap: true, extensions: proc { include_processor { process { next } } }
      expected_source <<~'END'
      before includes

      link:foobar.adoc[]

      after includes
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should not process link macro following include skipped by include processor when safe mode is secure' do
    run_scenario do
      input_source <<~'END'
      before includes

      include::ignored.adoc[]
      link:foobar.adoc[]

      after includes
      END

      reduce_options safe: :secure, sourcemap: true, extensions: proc { include_processor { process { next } } }
      expected_source <<~'END'
      before includes

      link:foobar.adoc[]

      after includes
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should skip empty include' do
    run_scenario do
      input_source <<~'END'
      before include
      include::empty.adoc[]
      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include
      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 1
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
      end)
    end
  end

  it 'should resolve include after empty include' do
    run_scenario do
      input_source <<~'END'
      before includes

      include::empty.adoc[]

      between includes

      include::single-line-paragraph.adoc[]

      after includes
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before includes


      between includes

      single-line paragraph

      after includes
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4, 6, 8]
      end)
    end
  end

  it 'should skip nested empty include' do
    run_scenario do
      include_source <<~'END'
      before include
      include::empty.adoc[]
      after include
      END

      input_source <<~END
      before top-level include

      include::#{include_file_basename}[]

      after top-level include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before top-level include

      before include
      after include

      after top-level include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
      end)
    end
  end

  it 'should remove trailing empty lines when sourcemap is enabled' do
    run_scenario do
      input_source <<~'END'
      before include


      include::empty.adoc[]
      END

      reduce_options sourcemap: true
      expected_source 'before include'
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 1
        (expect doc.blocks[0].lineno).to eql 1
      end)
    end
  end

  it 'should remove trailing empty lines when sourcemap is not enabled' do
    run_scenario do
      input_source <<~'END'
      before include


      include::empty.adoc[]
      END

      expected_source 'before include'
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 1
      end)
    end
  end

  it 'should not crash if reduced document is empty' do
    run_scenario do
      input_source 'include::empty.adoc[]'
      expected_source ''
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to be_empty
      end)
    end
  end

  it 'should skip include that custom include processor handles but does not push' do
    run_scenario do
      described_class::Extensions.register
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options safe: :secure, sourcemap: true, extensions: proc { include_processor { process { next } } }
      reduce { Asciidoctor.load_file input_file, reduce_options }
      expected_source <<~'END'
      before include


      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 2
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
      end)

      finally { described_class::Extensions.unregister }
    end
  end

  it 'should include lines pushed by custom include processor' do
    run_scenario do
      input_source <<~'END'
      before include

      include::custom-include.adoc[]

      after include
      END

      reduce_options sourcemap: true, extensions: (proc do
        include_processor do
          process do |_, reader, target, attrs|
            reader.push_include ['pushed first', '', 'pushed last'], target, target, 1, attrs
          end
        end
      end)

      expected_source <<~'END'
      before include

      pushed first

      pushed last

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
      end)
    end
  end

  it 'should include lines pushed by custom include processor when safe mode is secure' do
    run_scenario do
      input_source <<~'END'
      before include

      include::custom-include.adoc[]

      after include
      END

      reduce_options safe: :secure, sourcemap: true, extensions: (proc do
        include_processor do
          process do |_, reader, target, attrs|
            reader.push_include ['pushed first', '', 'pushed last'], target, target, 1, attrs
          end
        end
      end)

      expected_source <<~'END'
      before include

      pushed first

      pushed last

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
      end)
    end
  end

  it 'should not replace lines if the target line does not match the expected line' do
    run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options sourcemap: true, extensions: (proc do
        tree_processor do
          prefer
          process do |interim_doc|
            unless interim_doc.options[:reduced]
              interim_doc.reader.include_replacements[1][:line] = 'include::not-a-match[]'
            end
            nil
          end
        end
      end)

      expected_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      expected_log_messages [{ severity: :ERROR, message: '~include directive to reduce not found;', last: true }]
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should not rebuild document if no includes are found' do
    run_scenario do
      captured_interim_doc = nil
      input_source <<~'END'
      no includes to be found

      not a single one
      END

      reduce_options extensions: (proc do
        tree_processor do
          prefer
          process do |interim_doc|
            captured_interim_doc = interim_doc unless interim_doc.options[:reduced]
            nil
          end
        end
      end)

      verify do |doc|
        (expect captured_interim_doc).to be doc
      end
    end
  end

  it 'should resolve include with tag' do
    run_scenario do
      input_source <<~'END'
      before include

      include::with-include-tag.adoc[tag=body]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      Start of body.

      End of body.

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
      end)
    end
  end

  it 'should resolve include with tags' do
    run_scenario do
      input_source <<~'END'
      before include

      include::with-include-tags.adoc[tags=beginning;end]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      The beginning.
      The end.

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
      end)
    end
  end

  it 'should resolve include with lines' do
    run_scenario do
      include_source <<~'END'
      first paragraph, first line
      first paragraph, second line

      second paragraph, first line
      second paragraph, second line

      third paragraph

      fourth paragraph
      END

      input_source <<~END
      before include

      include::#{include_file_basename}[lines=2..7]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      first paragraph, second line

      second paragraph, first line
      second paragraph, second line

      third paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 5
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8, 10]
      end)
    end
  end

  it 'should resolve include with leveloffset' do
    run_scenario do
      include_source <<~'END'
      == Subsection

      === Nested Subsection
      END

      input_source <<~END
      == Section

      include::#{include_file_basename}[leveloffset=+1]

      == Another Section
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      == Section

      :leveloffset: +1

      == Subsection

      === Nested Subsection

      :leveloffset!:

      == Another Section
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by context: :section
        (expect blocks).to have_size 4
        (expect (blocks.map {|it| it.lineno })).to eql [1, 5, 7, 11]
      end)
    end
  end

  it 'should resolve includes inside include with leveloffset attribute' do
    run_scenario do
      include_source <<~'END'
      == Subsection

      include::no-includes.adoc[]

      === Nested Subsection

      include::multiple-paragraphs.adoc[]
      END

      input_source <<~END
      == Section

      include::#{include_file_basename}[leveloffset=+1]

      == Another Section
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      == Section

      :leveloffset: +1

      == Subsection

      no includes here

      just regular paragraph text

      === Nested Subsection

      first paragraph

      second paragraph
      with two lines

      :leveloffset!:

      == Another Section
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by context: :section
        (expect blocks).to have_size 4
        (expect (blocks.map {|it| it.lineno })).to eql [1, 5, 11, 20]
      end)
    end
  end

  it 'should resolve preprocessor conditional inside include with leveloffset attribute' do
    run_scenario do
      include_source <<~'END'
      == Subsection
      ifdef::show-details[]

      === Nested Subsection
      endif::[]
      END

      input_source <<~END
      == Section

      include::#{include_file_basename}[leveloffset=+1]

      == Another Section
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      == Section

      :leveloffset: +1

      == Subsection

      :leveloffset!:

      == Another Section
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by context: :section
        (expect blocks).to have_size 3
        (expect (blocks.map {|it| it.lineno })).to eql [1, 5, 9]
      end)
    end
  end

  it 'should resolve include between leveloffset attribute entries' do
    run_scenario do
      include_source <<~'END'
      == Subsection

      === Nested Subsection
      END

      input_source <<~END
      == Section

      :leveloffset: +1
      include::#{include_file_basename}[]

      :!leveloffset:
      == Another Section
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      == Section

      :leveloffset: +1
      == Subsection

      === Nested Subsection

      :!leveloffset:
      == Another Section
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by {|it| it.context != :document }
        (expect blocks).to have_size 4
        (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6, 9]
      end)
    end
  end

  it 'should preserve attribute entries in the document header' do
    run_scenario do
      input_source <<~'END'
      = Document Title
      :sectnums:
      :icons: font
      :toc:

      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      = Document Title
      :sectnums:
      :icons: font
      :toc:

      before include

      single-line paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [6, 8, 10]
        (expect (doc.attr? 'sectnums')).to be true
        (expect (doc.attr? 'icons', 'font')).to be true
        (expect (doc.attr? 'toc')).to be true
      end)
    end
  end

  it 'should use attribute defined in header when resolving include' do
    run_scenario do
      input_source <<~'END'
      = Book Title
      :chaptersdir: chapters

      include::{chaptersdir}/ch1.adoc[]
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      = Book Title
      :chaptersdir: chapters

      == Chapter One

      content
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by {|it| it.context != :document }
        (expect blocks).to have_size 3
        (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
      end)
    end
  end

  it 'should use attribute defined in body when resolving include' do
    run_scenario do
      input_source <<~'END'
      = Book Title
      :doctype: book

      Preamble.

      :includesdir: chapters
      include::{includesdir}/ch1.adoc[]

      :includesdir: appendices
      include::{includesdir}/appx1.adoc[]
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      = Book Title
      :doctype: book

      Preamble.

      :includesdir: chapters
      == Chapter One

      content

      :includesdir: appendices
      [appendix]
      == Installation

      content
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by {|it| it.context != :document }
        (expect blocks).to have_size 7
        (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 4, 7, 9, 13, 15]
      end)
    end
  end

  it 'should use attribute defined inside preprocessor conditional header when resolving include' do
    run_scenario do
      input_source <<~'END'
      = Book Title
      ifndef::chaptersdir[:chaptersdir: chapters]

      include::{chaptersdir}/ch1.adoc[]
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      = Book Title
      :chaptersdir: chapters

      == Chapter One

      content
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by {|it| it.context != :document }
        (expect blocks).to have_size 3
        (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
      end)
    end
  end

  it 'should use attribute passed to API when resolving include' do
    run_scenario do
      input_source <<~'END'
      = Book Title

      include::{chaptersdir}/ch1.adoc[]
      END

      reduce_options attributes: 'chaptersdir=chapters', sourcemap: true
      expected_source <<~'END'
      = Book Title

      == Chapter One

      content
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by {|it| it.context != :document }
        (expect blocks).to have_size 3
        (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should use attribute passed to API when resolving attribute value on include directive' do
    run_scenario do
      input_source <<~'END'
      before include

      include::with-include-tag.adoc[tag={tag}]

      after include
      END

      reduce_options attributes: 'tag=body', sourcemap: true
      expected_source <<~'END'
      before include

      Start of body.

      End of body.

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 4
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
      end)
    end
  end

  it 'should skip include when attribute in target cannot be resolved and attribute-missing=drop-line' do
    run_scenario do
      input_source <<~'END'
      = Book Title

      include::{chaptersdir}/ch1.adoc[]
      END

      reduce_options attributes: 'attribute-missing=drop-line', sourcemap: true
      expected_source '= Book Title'
      expected_log_messages [
        { severity: :INFO, message: '~dropping line' },
        { severity: :INFO, message: '~include dropped due to missing attribute:', last: true },
      ], using_log_level: :INFO
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.lineno).to eql 1
      end)
    end
  end

  it 'should drop lines containing preprocessor directive when condition resolves to true' do
    run_scenario do
      include_source <<~'END'
      primary content
      ifdef::flag[]
      conditional content
      endif::[]
      END

      input_source <<~END
      before include

      include::#{include_file_basename}[]

      after include
      END

      reduce_options attributes: { 'flag' => '' }, sourcemap: true
      expected_source <<~'END'
      before include

      primary content
      conditional content

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
      end)
    end
  end

  it 'should drop lines from start to end preprocessor directive when condition resolves to false' do
    run_scenario do
      include_source <<~'END'
      primary content
      ifdef::flag[]
      conditional content
      endif::[]
      END

      input_source <<~END
      before include

      include::#{include_file_basename}[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      primary content

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should drop single line preprocessor conditional that resolves to false' do
    run_scenario do
      input_source <<~'END'
      = Book Title
      ifndef::chaptersdir[:chaptersdir: chapters]

      include::{chaptersdir}/ch1.adoc[]
      END

      reduce_options attributes: { 'chaptersdir' => 'chapters' }, sourcemap: true
      expected_source <<~'END'
      = Book Title

      == Chapter One

      content
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.find_by {|it| it.context != :document }
        (expect blocks).to have_size 3
        (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5]
      end)
    end
  end

  it 'should reduce preprocessor conditional following a nested include' do
    run_scenario do
      include_source <<~'END'
      ifdef::flag[]
      before nested include
      endif::[]

      include::no-includes.adoc[]

      ifdef::flag[]
      after nested include
      endif::[]
      END

      input_source <<~END
      before include

      include::#{include_file_basename}[]

      after include
      END

      reduce_options attributes: { 'flag' => '' }, sourcemap: true
      expected_source <<~'END'
      before include

      before nested include

      no includes here

      just regular paragraph text

      after nested include

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        blocks = doc.blocks
        (expect blocks).to have_size 6
        (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
      end)
    end
  end

  it 'should reduce preprocessor conditional inside a file that has been included partially' do
    run_scenario do
      include_source <<~'END'
      not included

      //tag::select[]
      primary
      ifdef::flag[]
      conditional
      endif::[]
      //end::select[]

      also not included
      END

      input_source <<~END
      :flag:

      before include

      include::#{include_file}[tag=select]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      :flag:

      before include

      primary
      conditional

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 8]
      end)
    end
  end

  it 'should resolve include inside true preprocessor conditional' do
    run_scenario do
      input_source <<~'END'
      :flag:

      before include

      ifdef::flag[]
      include::single-line-paragraph.adoc[]
      endif::flag[]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      :flag:

      before include

      single-line paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7]
      end)
    end
  end

  it 'should not resolve include inside false preprocessor conditional' do
    run_scenario do
      input_source <<~'END'
      before include

      ifdef::no-such-attribute[]
      include::single-line-paragraph.adoc[]

      ifdef::backend[ignored]
      endif::[]
      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      before include

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 2
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
      end)
    end
  end

  it 'should resolve include inside true preprocessor conditional in file that has been included partially' do
    run_scenario do
      include_source <<~'END'
      not included

      //tag::select[]
      ifdef::flag[]
      include::single-line-paragraph.adoc[]
      endif::[]
      //end::select[]

      also not included
      END

      input_source <<~END
      :flag:

      before include

      include::#{include_file}[tag=select]

      after include
      END

      reduce_options sourcemap: true
      expected_source <<~'END'
      :flag:

      before include

      single-line paragraph

      after include
      END

      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 3
        (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7]
      end)
    end
  end

  it 'should keep preprocessor conditional if :preserve_conditionals option is set' do
    run_scenario do
      input_source <<~'END'
      before include

      ifdef::no-such-attribute[]
      include::single-line-paragraph.adoc[]

      ifdef::backend[ignored]
      endif::[]
      after include
      END

      reduce_options preserve_conditionals: true, sourcemap: true
      expected_source input_source
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 2
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 8]
      end)
    end
  end

  it 'should keep single line preprocessor conditional if :preserve_conditionals option is set and no includes' do
    run_scenario do
      input_source 'ifdef::asciidoctor-version[text]'
      reduce_options preserve_conditionals: true, sourcemap: true
      expected_source input_source
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect doc.blocks).to have_size 1
        (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
      end)
    end
  end

  it 'should not log messages generated by document if logger is turned off' do
    run_scenario do
      actual_logger = nil
      input_source <<~'END'
      image::{no-such-attribute}.png[]

      |===
      cell
      |===
      END

      reduce_options logger: nil, attributes: 'attribute-missing=warn'
      reduce (proc do |delegate|
        delegate.call.tap { actual_logger = Asciidoctor::LoggerManager.logger }
      end)
      expected_source input_source
      expected_log_messages nil
      verify (proc do |delegate, doc|
        delegate.call doc
        (expect actual_logger).to be_a Asciidoctor::NullLogger
      end)
    end
  end

  it 'should suppress log messages when reloading document' do
    run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      --
      after include
      END

      expected_source <<~'END'
      before include

      single-line paragraph

      --
      after include
      END

      expected_log_messages [{ severity: :WARN, message: 'unterminated open block', last: true }]
    end
  end
end
