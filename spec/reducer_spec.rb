# frozen_string_literal: true

describe Asciidoctor::Reducer do
  it 'should be able to require library from Ruby process' do
    # NOTE asciidoctor/reducer/version will already be required by Bundler
    script_file = fixture_file 'print_version.rb'
    output = %x(#{ruby} #{Shellwords.escape script_file}).lines.map(&:chomp)
    (expect output).to eql [described_class::VERSION, 'loaded']
  end

  it 'should register extensions globally when asciidoctor/reducer is required' do
    $".delete ::File.expand_path 'lib/asciidoctor/reducer.rb', (::File.dirname __dir__)
    (expect require 'asciidoctor/reducer').not_to be_nil
    (expect Asciidoctor::Extensions.groups).to have_key described_class::Extensions.key
  ensure
    described_class::Extensions.unregister
  end

  it 'should be able to require library using the alias asciidoctor-reducer' do
    $".delete ::File.expand_path 'lib/asciidoctor/reducer.rb', (::File.dirname __dir__)
    (expect require 'asciidoctor-reducer').not_to be_nil
    (expect Asciidoctor::Extensions.groups).to have_key described_class::Extensions.key
  ensure
    described_class::Extensions.unregister
  end

  it 'should load document with no includes' do
    doc = (scenario = create_scenario do
      input_source <<~'END'
      no includes to be found here

      not a single one
      END

      expected_source input_source
    end).run
    (expect doc.options[:reduced]).to be_falsy
    (expect doc.blocks).to have_size 2
    (expect doc.sourcemap).to be true
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
    input_file = scenario.input_file
    (expect doc.attr 'docname').to eql (File.basename input_file, '.adoc')
    (expect doc.attr 'docfile').to eql input_file
    (expect doc.attr 'docdir').to eql (File.dirname input_file)
  end

  it 'should not enable sourcemap on document with no includes' do
    doc = run_scenario do
      input_source <<~'END'
      no includes to be found here

      not a single one
      END

      reduce_options sourcemap: false

      expected_source input_source
    end
    (expect doc.options[:reduced]).to be_falsy
    (expect doc.sourcemap).to be_falsy
    (expect doc.blocks[0].source_location).to be_nil
  end

  it 'should resolve top-level include with no nested includes' do
    doc = (scenario = create_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      END
    end).run
    (expect doc.options[:reduced]).to be true
    (expect doc.blocks).to have_size 4
    (expect doc.sourcemap).to be true
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
    input_file = scenario.input_file
    (expect (doc.blocks.map {|it| it.file }).uniq).to eql [input_file]
    (expect doc.attr 'docname').to eql (File.basename input_file, '.adoc')
    (expect doc.attr 'docfile').to eql input_file
    (expect doc.attr 'docdir').to eql (File.dirname input_file)
    (expect doc.catalog[:includes]['no-includes']).to be true
  end

  it 'should not enable sourcemap on reduced document' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END

      reduce_options sourcemap: false

      expected_source <<~'END'
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      END
    end
    (expect doc.options[:reduced]).to be_falsy
    (expect doc.sourcemap).to be_falsy
    (expect doc.blocks[0].source_location).to be_nil
  end

  it 'should not reload document with includes if sourcemap is not enabled' do
    docs = []
    reduced_doc = run_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END

      reduce_options sourcemap: false, extensions: (proc do
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

      just good old-fashioned paragraph text

      after include
      END
    end
    (expect docs).to have_size 1
    (expect docs[0].object_id).to eql reduced_doc.object_id
    (expect reduced_doc.catalog[:includes]['no-includes']).to be true
  end

  it 'should resolve top-level include with nested include' do
    doc = (scenario = create_scenario do
      include_file = create_include_file <<~'END'
      before nested include

      include::no-includes.adoc[]

      after nested include
      END

      input_source <<~END
      before include

      include::#{include_file}[]

      after include
      END

      expected_source <<~'END'
      before include

      before nested include

      no includes here

      just good old-fashioned paragraph text

      after nested include

      after include
      END
    end).run
    (expect doc.blocks).to have_size 6
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
    (expect (doc.blocks.map {|it| it.file }).uniq).to eql [scenario.input_file]
  end

  it 'should resolve nested include relative to include file' do
    doc = reduce_file fixture_file 'parent-with-nested-include-in-subdir.adoc'
    expected_source = <<~'END'.chomp
    before include

    before relative include

    contents of relative include

    after relative include

    after include
    END
    (expect doc).to have_source expected_source
    (expect doc.blocks).to have_size 5
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
  end

  it 'should resolve include with single line paragraph' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      single line paragraph

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should skip escaped include' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      \include::not-processed.adoc[]

      after include
      END

      expected_source input_source
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should resolve include at start of document' do
    doc = run_scenario do
      input_source <<~'END'
      include::single-line-paragraph.adoc[]

      after include
      END

      expected_source <<~'END'
      single line paragraph

      after include
      END
    end
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include at end of document' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]
      END

      expected_source <<~'END'
      before include

      single line paragraph
      END
    end
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include with multiline paragraph' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::multiline-paragraph.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      first line
      second line
      third line

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 7]
  end

  it 'should resolve include with multiple paragraphs' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::multiple-paragraphs.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      first paragraph

      second paragraph
      with two lines

      after include
      END
    end
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8]
  end

  it 'should resolve adjacent includes' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]
      include::single-line-paragraph.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      single line paragraph
      single line paragraph

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should resolve include that follows include with nested include' do
    doc = run_scenario do
      input_source <<~'END'
      before

      include::include-with-include.adoc[]

      then

      include::no-includes.adoc[]

      after
      END

      expected_source <<~'END'
      before

      before nested include

      no includes here

      just good old-fashioned paragraph text

      after nested include

      then

      no includes here

      just good old-fashioned paragraph text

      after
      END
    end
    (expect doc.blocks).to have_size 9
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11, 13, 15, 17]
  end

  it 'should assign same line number to preamble and its paragraph' do
    doc = run_scenario do
      input_source <<~'END'
      = Document Title

      include::single-line-paragraph.adoc[]

      == Chapter A

      == Chapter B
      END

      expected_source <<~'END'
      = Document Title

      single line paragraph

      == Chapter A

      == Chapter B
      END
    end
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 5
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 3, 5, 7]
  end

  it 'should flag top-level include that cannot be resolved as an unresolved directive' do
    (expect do
      doc = run_scenario do
        input_source <<~'END'
        before include

        include::no-such-file.adoc[]

        after include
        END

        expected_source <<~END
        before include

        Unresolved directive in #{File.basename input_file} - include::no-such-file.adoc[]

        after include
        END
      end
      (expect doc.blocks).to have_size 3
      (expect doc.blocks[1].source).to start_with 'Unresolved directive'
      (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
    end).to log_messages [{ severity: :ERROR, message: '~include file not found:', last: true }]
  end

  it 'should resolve include after unresolved include' do
    doc = nil
    (expect do
      doc = reduce_file fixture_file 'parent-with-include-after-unresolved-include.adoc'
    end).to log_messages [{ severity: :ERROR, message: '~include file not found:', last: true }]
    expected_lines = <<~'END'.chomp.split ?\n
    :optional:

    before includes

    Unresolved directive in parent-with-include-after-unresolved-include.adoc - include::no-such-file.adoc[{optional}]

    between includes

    single line paragraph

    after includes
    END
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect doc.blocks[1].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7, 9, 11]
  end

  it 'should resolve include after unresolved optional include' do
    doc = nil
    (expect do
      doc = reduce_file (fixture_file 'parent-with-include-after-unresolved-include.adoc'),
        attributes: { 'optional' => 'opts=optional' }
    end).to log_messages [{ severity: :INFO, message: '~optional include dropped', last: true }], using_log_level: :INFO
    expected_lines = <<~'END'.chomp.split ?\n
    :optional:

    before includes


    between includes

    single line paragraph

    after includes
    END
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 6, 8, 10]
  end

  it 'should skip optional top-level include that cannot be resolved' do
    doc = nil
    (expect do
      doc = reduce_file fixture_file 'parent-with-optional-unresolved-include.adoc'
    end).to log_messages [{ severity: :INFO, message: '~optional include dropped', last: true }], using_log_level: :INFO
    expected_lines = <<~'END'.chomp.split ?\n
    before include


    after include
    END
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
  end

  it 'should flag nested include that cannot be resolved as an unresolved directive' do
    doc = nil
    (expect do
      doc = reduce_file fixture_file 'parent-with-nested-unresolved-include.adoc'
    end).to log_messages [{ severity: :ERROR, message: '~include file not found:', last: true }]
    expected_lines = <<~'END'.chomp.split ?\n
    before top-level include

    before include

    Unresolved directive in parent-with-unresolved-include.adoc - include::no-such-file.adoc[]

    after include

    after top-level include
    END
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect doc.blocks[2].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
  end

  it 'should flag include as an unresolved directive if target is empty' do
    doc = nil
    (expect do
      doc = reduce_file fixture_file 'parent-with-include-with-empty-target.adoc'
    end).to log_messages [
      { severity: :WARN, message: '~include dropped because resolved target is blank:', last: true },
    ]
    expected_lines = <<~'END'.chomp.split ?\n
    before include

    Unresolved directive in parent-with-include-with-empty-target.adoc - include::{empty}[]

    after include
    END
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should reduce includes when safe mode is server' do
    doc = (scenario = create_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options safe: :server

      expected_source <<~'END'
      before include

      single line paragraph

      after include
      END
    end).run
    input_file = scenario.input_file
    (expect doc.attr 'docname').to eql (File.basename input_file, '.adoc')
    (expect doc.attr 'docfile').to eql (File.basename input_file)
    (expect doc.attr 'docdir').to be_empty
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should replace includes with links if safe mode is secure' do
    doc = run_scenario do
      input_source <<~'END'
      before includes

      include::single-line-paragraph.adoc[]

      include::multiline-paragraph.adoc[]

      after includes
      END

      reduce_options safe: :secure

      expected_source <<~'END'
      before includes

      link:single-line-paragraph.adoc[role=include]

      link:multiline-paragraph.adoc[role=include]

      after includes
      END
    end
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should replace include with link if target is URL and allow-uri-read is not set' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::https://example.org/intro.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      link:https://example.org/intro.adoc[role=include]

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should reduce remote include if allow-uri-read is set' do
    doc = with_local_webserver do |base_url|
      described_class.reduce <<~END, attributes: { 'allow-uri-read' => '' }
      before include

      include::#{base_url}/no-includes.adoc[]

      after include
      END
    end
    expected_lines = <<~'END'.chomp.split ?\n
    before include

    no includes here

    just good old-fashioned paragraph text

    after include
    END
    (expect doc.source_lines).to eql expected_lines
  end

  it 'should reduce remote include with include if allow-uri-read is set' do
    doc = with_local_webserver do |base_url|
      described_class.reduce <<~END, attributes: { 'allow-uri-read' => '' }
      before include

      include::#{base_url}/include-with-include.adoc[]

      after include
      END
    end
    expected_lines = <<~'END'.chomp.split ?\n
    before include

    before nested include

    no includes here

    just good old-fashioned paragraph text

    after nested include

    after include
    END
    (expect doc.source_lines).to eql expected_lines
  end

  it 'should not process link macro following include skipped by include processor when safe mode is not secure' do
    doc = run_scenario do
      input_source <<~'END'
      before includes

      include::ignored.adoc[]
      link:foobar.adoc[]

      after includes
      END

      reduce_options extensions: proc { include_processor { process { next } } }

      expected_source <<~'END'
      before includes

      link:foobar.adoc[]

      after includes
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should not process link macro following include skipped by include processor when safe mode is secure' do
    doc = run_scenario do
      input_source <<~'END'
      before includes

      include::ignored.adoc[]
      link:foobar.adoc[]

      after includes
      END

      reduce_options safe: :secure, extensions: proc { include_processor { process { next } } }

      expected_source <<~'END'
      before includes

      link:foobar.adoc[]

      after includes
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should skip empty include' do
    doc = run_scenario do
      input_source <<~'END'
      before include
      include::empty.adoc[]
      after include
      END

      expected_source <<~'END'
      before include
      after include
      END
    end
    (expect doc.blocks).to have_size 1
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
  end

  it 'should resolve include after empty include' do
    doc = run_scenario do
      input_source <<~'END'
      before includes

      include::empty.adoc[]

      between includes

      include::single-line-paragraph.adoc[]

      after includes
      END

      expected_source <<~'END'
      before includes


      between includes

      single line paragraph

      after includes
      END
    end
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4, 6, 8]
  end

  it 'should skip nested empty include' do
    doc = run_scenario do
      include_file = create_include_file <<~'END'
      before include
      include::empty.adoc[]
      after include
      END

      input_source <<~END
      before top-level include

      include::#{include_file}[]

      after top-level include
      END

      expected_source <<~'END'
      before top-level include

      before include
      after include

      after top-level include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should remove trailing empty lines when sourcemap is enabled' do
    doc = run_scenario do
      input_source <<~'END'
      before include


      include::empty.adoc[]
      END

      expected_source 'before include'
    end
    (expect doc.blocks).to have_size 1
    (expect doc.blocks[0].lineno).to eql 1
  end

  it 'should remove trailing empty lines when sourcemap is not enabled' do
    doc = run_scenario do
      input_source <<~'END'
      before include


      include::empty.adoc[]
      END

      reduce_options sourcemap: false

      expected_source 'before include'
    end
    (expect doc.blocks).to have_size 1
  end

  it 'should not crash if reduced document is empty' do
    doc = run_scenario do
      input_source 'include::empty.adoc[]'

      reduce_options sourcemap: false

      expected_source ''
    end
    (expect doc.blocks).to be_empty
  end

  it 'should skip include that custom include processor handles but does not push' do
    described_class::Extensions.register
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options safe: :secure, sourcemap: true, extensions: proc { include_processor { process { next } } }

      reduce { Asciidoctor.load_file input_file, *reduce_options }

      expected_source <<~'END'
      before include


      after include
      END
    end
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
  ensure
    described_class::Extensions.unregister
  end

  it 'should include lines pushed by custom include processor' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::custom-include.adoc[]

      after include
      END

      reduce_options extensions: (proc do
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
    end
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should include lines pushed by custom include processor when safe mode is secure' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::custom-include.adoc[]

      after include
      END

      reduce_options safe: :secure, extensions: (proc do
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
    end
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should not replace lines if the target line does not match the expected line' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      reduce_options extensions: (proc do
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
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should not rebuild document if no includes are found' do
    captured_interim_doc = nil
    doc = run_scenario do
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
    end
    (expect captured_interim_doc).to be doc
  end

  it 'should resolve include with tag' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::include-with-tag.adoc[tag=body]

      after include
      END

      expected_source <<~'END'
      before include

      Start of body.

      End of body.

      after include
      END
    end
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should resolve include with tags' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::include-with-tags.adoc[tags=beginning;end]

      after include
      END

      expected_source <<~'END'
      before include

      The beginning.
      The end.

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should resolve include with lines' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::include-by-lines.adoc[lines=2..7]

      after include
      END

      expected_source <<~'END'
      before include

      first paragraph, second line

      second paragraph, first line
      second paragraph, second line

      third paragraph

      after include
      END
    end
    (expect doc.blocks).to have_size 5
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8, 10]
  end

  it 'should resolve include with leveloffset' do
    doc = run_scenario do
      input_source <<~'END'
      == Section

      include::subsections.adoc[leveloffset=+1]

      == Another Section
      END

      expected_source <<~'END'
      == Section

      :leveloffset: +1

      == Subsection

      === Nested Subsection

      :leveloffset!:

      == Another Section
      END
    end
    blocks = doc.find_by context: :section
    (expect blocks).to have_size 4
    (expect (blocks.map {|it| it.lineno })).to eql [1, 5, 7, 11]
  end

  it 'should resolve include between leveloffset attribute entries' do
    doc = run_scenario do
      input_source <<~'END'
      == Section

      :leveloffset: +1
      include::subsections.adoc[]

      :!leveloffset:
      == Another Section
      END

      expected_source <<~'END'
      == Section

      :leveloffset: +1
      == Subsection

      === Nested Subsection

      :!leveloffset:
      == Another Section
      END
    end
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 4
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6, 9]
  end

  it 'should preserve attribute entries in the document header' do
    doc = run_scenario do
      input_source <<~'END'
      = Document Title
      :sectnums:
      :icons: font
      :toc:

      before include

      include::single-line-paragraph.adoc[]

      after include
      END

      expected_source <<~'END'
      = Document Title
      :sectnums:
      :icons: font
      :toc:

      before include

      single line paragraph

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [6, 8, 10]
    (expect (doc.attr? 'sectnums')).to be true
    (expect (doc.attr? 'icons', 'font')).to be true
    (expect (doc.attr? 'toc')).to be true
  end

  it 'should use attribute defined in header when resolving include' do
    doc = run_scenario do
      input_source <<~'END'
      = Book Title
      :chaptersdir: chapters

      include::{chaptersdir}/ch1.adoc[]
      END

      expected_source <<~'END'
      = Book Title
      :chaptersdir: chapters

      == Chapter One

      content
      END
    end
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
  end

  it 'should use attribute defined in body when resolving include' do
    doc = run_scenario do
      input_source <<~'END'
      = Book Title
      :doctype: book

      Preamble.

      :includesdir: chapters
      include::{includesdir}/ch1.adoc[]

      :includesdir: appendices
      include::{includesdir}/appx1.adoc[]
      END

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
    end
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 7
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 4, 7, 9, 13, 15]
  end

  it 'should use attribute defined inside preprocessor conditional header when resolving include' do
    doc = run_scenario do
      input_source <<~'END'
      = Book Title
      ifndef::chaptersdir[:chaptersdir: chapters]

      include::{chaptersdir}/ch1.adoc[]
      END

      expected_source <<~'END'
      = Book Title
      :chaptersdir: chapters

      == Chapter One

      content
      END
    end
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
  end

  it 'should use attribute passed to API when resolving include' do
    doc = run_scenario do
      input_source <<~'END'
      = Book Title

      include::{chaptersdir}/ch1.adoc[]
      END

      reduce_options attributes: 'chaptersdir=chapters'

      expected_source <<~'END'
      = Book Title

      == Chapter One

      content
      END
    end
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should use attribute passed to API when resolving attribute value on include directive' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::include-with-tag.adoc[tag={tag}]

      after include
      END

      reduce_options attributes: 'tag=body'

      expected_source <<~'END'
      before include

      Start of body.

      End of body.

      after include
      END
    end
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should skip include when attribute in target cannot be resolved and attribute-missing=drop-line' do
    (expect do
      doc = run_scenario do
        input_source <<~'END'
        = Book Title

        include::{chaptersdir}/ch1.adoc[]
        END

        reduce_options attributes: 'attribute-missing=drop-line'

        expected_source '= Book Title'
      end
      (expect doc.lineno).to eql 1
    end).to log_messages [
      { severity: :INFO, message: '~dropping line', at: 0 },
      { severity: :INFO, message: '~include dropped due to missing attribute:', at: 1, last: true },
    ], using_log_level: :INFO
  end

  it 'should drop lines containing preprocessor directive when condition resolves to true' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::preprocessor-conditional.adoc[]

      after include
      END

      reduce_options attributes: { 'flag' => '' }

      expected_source <<~'END'
      before include

      primary content
      conditional content

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should drop lines from start to end preprocessor directive when condition resolves to false' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::preprocessor-conditional.adoc[]

      after include
      END

      expected_source <<~'END'
      before include

      primary content

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should drop single line preprocessor conditional that resolves to false' do
    doc = run_scenario do
      input_source <<~'END'
      = Book Title
      ifndef::chaptersdir[:chaptersdir: chapters]

      include::{chaptersdir}/ch1.adoc[]
      END

      reduce_options attributes: { 'chaptersdir' => 'chapters' }

      expected_source <<~'END'
      = Book Title

      == Chapter One

      content
      END
    end
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should reduce preprocessor conditional following a nested include' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::preprocessor-conditionals-and-include.adoc[]

      after include
      END

      reduce_options attributes: { 'flag' => '' }

      expected_source <<~'END'
      before include

      before nested include

      no includes here

      just good old-fashioned paragraph text

      after nested include

      after include
      END
    end
    blocks = doc.blocks
    (expect blocks).to have_size 6
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
  end

  it 'should resolve include inside true preprocessor conditional' do
    doc = run_scenario do
      input_source <<~'END'
      :flag:

      before include

      ifdef::flag[]
      include::single-line-paragraph.adoc[]
      endif::flag[]

      after include
      END

      expected_source <<~'END'
      :flag:

      before include

      single line paragraph

      after include
      END
    end
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7]
  end

  it 'should not resolve include inside false preprocessor conditional' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      ifdef::no-such-attribute[]
      include::single-line-paragraph.adoc[]

      ifdef::backend[ignored]
      endif::[]
      after include
      END

      expected_source <<~'END'
      before include

      after include
      END
    end
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should keep preprocessor conditional if :preserve_conditionals option is set' do
    doc = run_scenario do
      input_source <<~'END'
      before include

      ifdef::no-such-attribute[]
      include::single-line-paragraph.adoc[]

      ifdef::backend[ignored]
      endif::[]
      after include
      END

      reduce_options preserve_conditionals: true

      expected_source input_source
    end
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 8]
  end

  it 'should keep single line preprocessor conditional if :preserve_conditionals option is set and no includes' do
    doc = run_scenario do
      input_source 'ifdef::asciidoctor-version[text]'

      reduce_options preserve_conditionals: true

      expected_source input_source
    end
    (expect doc.blocks).to have_size 1
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
  end

  it 'should not log messages generated by document if null logger is specified' do
    with_memory_logger do |logger|
      null_logger = Asciidoctor::NullLogger.new
      run_scenario do
        input_source <<~'END'
        image::{no-such-attribute}.png[]

        |===
        cell
        |===
        END

        reduce_options sourcemap: false, logger: null_logger, attributes: 'attribute-missing=warn'

        expected_source input_source
      end
      (expect logger.messages).to be_empty
      (expect Asciidoctor::LoggerManager.logger).to be null_logger
    end
  end

  it 'should suppress log messages when reloading document' do
    (expect do
      run_scenario do
        input_source <<~'END'
        before include

        include::single-line-paragraph.adoc[]

        --
        after include
        END

        expected_source <<~'END'
        before include

        single line paragraph

        --
        after include
        END
      end
    end).to log_messages [{ severity: :WARN, message: 'unterminated open block', last: true }]
  end
end
