# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::Reducer do
  it 'should be able to require library from Ruby process' do
    # NOTE asciidoctor/reducer/version will already be required by Bundler
    script_file = fixture_file 'print_version.rb'
    output = %x(#{ruby} #{Shellwords.escape script_file}).lines.map(&:chomp)
    (expect output).to eql [described_class::VERSION, 'loaded']
  end

  it 'should register extensions globally when asciidoctor/reducer is required' do
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
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      no includes to be found here

      not a single one
      EOS

      expected_source input_source
    end
    (expect doc.options[:reduced]).to be_falsy
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 2
    (expect doc.sourcemap).to be true
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
    input_file = scenario.input_file
    (expect doc.attr 'docname').to eql (File.basename input_file, '.adoc')
    (expect doc.attr 'docfile').to eql input_file
    (expect doc.attr 'docdir').to eql (File.dirname input_file)
  end

  it 'should not enable sourcemap on document with no includes' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      no includes to be found here

      not a single one
      EOS

      reduce_options sourcemap: false

      expected_source input_source
    end
    (expect doc.options[:reduced]).to be_falsy
    (expect doc).to have_source scenario.expected_source
    (expect doc.sourcemap).to be_falsy
    (expect doc.blocks[0].source_location).to be_nil
  end

  it 'should resolve top-level include with no nested includes' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::no-includes.adoc[]

      after include
      EOS

      expected_source <<~'EOS'
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
    end
    (expect doc.options[:reduced]).to be true
    (expect doc).to have_source scenario.expected_source
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
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::no-includes.adoc[]

      after include
      EOS

      reduce_options sourcemap: false

      expected_source <<~'EOS'
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
    end
    (expect doc.options[:reduced]).to be_falsy
    (expect doc).to have_source scenario.expected_source
    (expect doc.sourcemap).to be_falsy
    (expect doc.blocks[0].source_location).to be_nil
  end

  it 'should not reload document with includes if sourcemap is not enabled' do
    docs = []
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::no-includes.adoc[]

      after include
      EOS

      reduce_options sourcemap: false, extensions: (proc do
        tree_processor do
          prefer
          process do |doc|
            docs << doc
            nil
          end
        end
      end)

      expected_source <<~'EOS'
      before include

      no includes here

      just good old-fashioned paragraph text

      after include
      EOS
    end
    (expect docs).to have_size 1
    (expect docs[0].object_id).to eql doc.object_id
    (expect doc).to have_source scenario.expected_source
    (expect doc.catalog[:includes]['no-includes']).to be true
  end

  it 'should resolve top-level include with nested include' do
    scenario, doc = create_scenario do
      include_file = create_include_file <<~'EOS'
      before nested include

      include::no-includes.adoc[]

      after nested include
      EOS

      input_source <<~EOS
      before include

      include::#{include_file}[]

      after include
      EOS

      expected_source <<~'EOS'
      before include

      before nested include

      no includes here

      just good old-fashioned paragraph text

      after nested include

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 6
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
    (expect (doc.blocks.map {|it| it.file }).uniq).to eql [scenario.input_file]
  end

  it 'should resolve nested include relative to include file' do
    doc = reduce_file fixture_file 'parent-with-nested-include-in-subdir.adoc'
    expected_source = <<~'EOS'.chomp
    before include

    before relative include

    contents of relative include

    after relative include

    after include
    EOS
    (expect doc).to have_source expected_source
    (expect doc.blocks).to have_size 5
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
  end

  it 'should resolve include with single line paragraph' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::single-line-paragraph.adoc[]

      after include
      EOS

      expected_source <<~'EOS'
      before include

      single line paragraph

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should skip escaped include' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      \include::multiple-paragraphs.adoc[]

      after include
      EOS

      expected_source input_source
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should resolve include at start of document' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      include::single-line-paragraph.adoc[]

      after include
      EOS

      expected_source <<~'EOS'
      single line paragraph

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include at end of document' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::single-line-paragraph.adoc[]
      EOS

      expected_source <<~'EOS'
      before include

      single line paragraph
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should resolve include with multiline paragraph' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::multiline-paragraph.adoc[]

      after include
      EOS

      expected_source <<~'EOS'
      before include

      first line
      second line
      third line

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 7]
  end

  it 'should resolve include with multiple paragraphs' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::multiple-paragraphs.adoc[]

      after include
      EOS

      expected_source <<~'EOS'
      before include

      first paragraph

      second paragraph
      with two lines

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8]
  end

  it 'should resolve adjacent includes' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::single-line-paragraph.adoc[]
      include::single-line-paragraph.adoc[]

      after include
      EOS

      expected_source <<~'EOS'
      before include

      single line paragraph
      single line paragraph

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should resolve include that follows include with nested include' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before

      include::include-with-include.adoc[]

      then

      include::no-includes.adoc[]

      after
      EOS

      expected_source <<~'EOS'
      before

      before nested include

      no includes here

      just good old-fashioned paragraph text

      after nested include

      then

      no includes here

      just good old-fashioned paragraph text

      after
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 9
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11, 13, 15, 17]
  end

  it 'should assign same line number to preamble and its paragraph' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      = Document Title

      include::single-line-paragraph.adoc[]

      == Chapter A

      == Chapter B
      EOS

      expected_source <<~'EOS'
      = Document Title

      single line paragraph

      == Chapter A

      == Chapter B
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 5
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 3, 5, 7]
  end

  it 'should flag top-level include that cannot be resolved as an unresolved directive' do
    doc = nil
    with_memory_logger do |logger|
      doc = reduce_file fixture_file 'parent-with-unresolved-include.adoc'
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Unresolved directive in parent-with-unresolved-include.adoc - include::no-such-file.adoc[]

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect doc.blocks[1].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should resolve include after unresolved include' do
    doc = nil
    with_memory_logger do |logger|
      doc = reduce_file fixture_file 'parent-with-include-after-unresolved-include.adoc'
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    :optional:

    before includes

    Unresolved directive in parent-with-include-after-unresolved-include.adoc - include::no-such-file.adoc[{optional}]

    between includes

    single line paragraph

    after includes
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect doc.blocks[1].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7, 9, 11]
  end

  it 'should resolve include after unresolved optional include' do
    doc = nil
    with_memory_logger do |logger|
      doc = reduce_file (fixture_file 'parent-with-include-after-unresolved-include.adoc'),
        attributes: { 'optional' => 'opts=optional' }
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    :optional:

    before includes


    between includes

    single line paragraph

    after includes
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 6, 8, 10]
  end

  it 'should skip optional top-level include that cannot be resolved' do
    doc = nil
    with_memory_logger do |logger|
      doc = reduce_file fixture_file 'parent-with-optional-unresolved-include.adoc'
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include


    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
  end

  it 'should flag nested include that cannot be resolved as an unresolved directive' do
    doc = nil
    with_memory_logger do |logger|
      doc = reduce_file fixture_file 'parent-with-nested-unresolved-include.adoc'
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'include file not found'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before top-level include

    before include

    Unresolved directive in parent-with-unresolved-include.adoc - include::no-such-file.adoc[]

    after include

    after top-level include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect doc.blocks[2].source).to start_with 'Unresolved directive'
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9]
  end

  it 'should flag include as an unresolved directive if target is empty' do
    doc = nil
    with_memory_logger do |logger|
      doc = reduce_file fixture_file 'parent-with-include-with-empty-target.adoc'
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:message][:text]).to include 'resolved target is blank'
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Unresolved directive in parent-with-include-with-empty-target.adoc - include::{empty}[]

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should reduce includes when safe mode is server' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::single-line-paragraph.adoc[]

      after include
      EOS

      reduce_options safe: :server

      expected_source <<~'EOS'
      before include

      single line paragraph

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    input_file = scenario.input_file
    (expect doc.attr 'docname').to eql (File.basename input_file, '.adoc')
    (expect doc.attr 'docfile').to eql (File.basename input_file)
    (expect doc.attr 'docdir').to be_empty
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should replace includes with links if safe mode is secure' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before includes

      include::single-line-paragraph.adoc[]

      include::multiline-paragraph.adoc[]

      after includes
      EOS

      reduce_options safe: :secure

      expected_source <<~'EOS'
      before includes

      link:single-line-paragraph.adoc[role=include]

      link:multiline-paragraph.adoc[role=include]

      after includes
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should replace include with link if target is URL and allow-uri-read is not set' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include

      include::https://example.org/intro.adoc[]

      after include
      EOS

      expected_source <<~'EOS'
      before include

      link:https://example.org/intro.adoc[role=include]

      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should reduce remote include if allow-uri-read is set' do
    doc = with_local_webserver do |base_url|
      described_class.reduce <<~EOS, attributes: { 'allow-uri-read' => '' }
      before include

      include::#{base_url}/no-includes.adoc[]

      after include
      EOS
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    no includes here

    just good old-fashioned paragraph text

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
  end

  it 'should reduce remote include with include if allow-uri-read is set' do
    doc = with_local_webserver do |base_url|
      described_class.reduce <<~EOS, attributes: { 'allow-uri-read' => '' }
      before include

      include::#{base_url}/include-with-include.adoc[]

      after include
      EOS
    end
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    before nested include

    no includes here

    just good old-fashioned paragraph text

    after nested include

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
  end

  it 'should not process link macro following include skipped by include processor when safe mode is not secure' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before includes

      include::ignored.adoc[]
      link:foobar.adoc[]

      after includes
      EOS

      reduce_options extensions: (proc do
        include_processor { process { next } }
      end)

      expected_source <<~'EOS'
      before includes

      link:foobar.adoc[]

      after includes
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should not process link macro following include skipped by include processor when safe mode is secure' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before includes

      include::ignored.adoc[]
      link:foobar.adoc[]

      after includes
      EOS

      reduce_options safe: :secure, extensions: (proc do
        include_processor { process { next } }
      end)

      expected_source <<~'EOS'
      before includes

      link:foobar.adoc[]

      after includes
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should skip empty include' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include
      include::empty.adoc[]
      after include
      EOS

      expected_source <<~'EOS'
      before include
      after include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 1
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
  end

  it 'should resolve include after empty include' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before includes

      include::empty.adoc[]

      between includes

      include::single-line-paragraph.adoc[]

      after includes
      EOS

      expected_source <<~'EOS'
      before includes


      between includes

      single line paragraph

      after includes
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4, 6, 8]
  end

  it 'should skip nested empty include' do
    scenario, doc = create_scenario do
      include_file = create_include_file <<~'EOS'
      before include
      include::empty.adoc[]
      after include
      EOS

      input_source <<~EOS
      before top-level include

      include::#{include_file}[]

      after top-level include
      EOS

      expected_source <<~'EOS'
      before top-level include

      before include
      after include

      after top-level include
      EOS
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should remove trailing empty lines when sourcemap is enabled' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include


      include::empty.adoc[]
      EOS

      expected_source 'before include'
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 1
    (expect doc.blocks[0].lineno).to eql 1
  end

  it 'should remove trailing empty lines when sourcemap is not enabled' do
    scenario, doc = create_scenario do
      input_source <<~'EOS'
      before include


      include::empty.adoc[]
      EOS

      reduce_options sourcemap: false

      expected_source 'before include'
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to have_size 1
  end

  it 'should not crash if reduced document is empty' do
    scenario, doc = create_scenario do
      input_source 'include::empty.adoc[]'

      reduce_options sourcemap: false

      expected_source ''
    end
    (expect doc).to have_source scenario.expected_source
    (expect doc.blocks).to be_empty
  end

  it 'should skip include that custom include processor handles but does not push' do
    described_class::Extensions.register
    doc = Asciidoctor.load_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'),
      safe: :secure, sourcemap: true, extensions: proc { include_processor { process { next } } }
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include


    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 4]
  ensure
    described_class::Extensions.unregister
  end

  it 'should include lines pushed by custom include processor' do
    doc = reduce_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), extensions: (proc do
      include_processor do
        process do |_, reader, target, attrs|
          reader.push_include ['pushed first', '', 'pushed last'], target, target, 1, attrs
        end
      end
    end)
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    pushed first

    pushed last

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should include lines pushed by custom include processor when safe mode is secure' do
    doc = reduce_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), safe: :secure,
      extensions: (proc do
        include_processor do
          process do |_, reader, target, attrs|
            reader.push_include ['pushed first', '', 'pushed last'], target, target, 1, attrs
          end
        end
      end)
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    pushed first

    pushed last

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should not replace lines if the target line does not match the expected line' do
    doc = reduce_file (fixture_file 'parent-with-include-with-single-line-paragraph.adoc'), extensions: (proc do
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
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    include::single-line-paragraph.adoc[]

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should not rebuild document if no includes are found' do
    captured_interim_doc = nil
    scenario = create_scenario do
      input_source <<~'EOS'
      no includes to be found

      not a single one
      EOS

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
    expect(captured_interim_doc).to be scenario.doc
  end

  it 'should resolve include with tag' do
    doc = reduce_file fixture_file 'parent-with-include-with-tag.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Start of body.

    End of body.

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should resolve include with tags' do
    doc = reduce_file fixture_file 'parent-with-include-with-tags.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    The beginning.
    The end.

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should resolve include with lines' do
    doc = reduce_file fixture_file 'parent-with-include-with-lines.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    first paragraph, second line

    second paragraph, first line
    second paragraph, second line

    third paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 5
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 8, 10]
  end

  it 'should resolve include with leveloffset' do
    doc = reduce_file fixture_file 'parent-with-include-with-leveloffset.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Document Title

    == Section

    :leveloffset: +1

    == Subsection

    === Nested Subsection

    :leveloffset!:

    == Another Section
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by context: :section
    (expect blocks).to have_size 5
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 7, 9, 13]
  end

  it 'should resolve include between leveloffset attribute entries' do
    doc = reduce_file fixture_file 'parent-with-leveloffset-and-include.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Document Title

    == Section

    :leveloffset: +1
    == Subsection

    === Nested Subsection

    :!leveloffset:
    == Another Section
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 5
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 6, 8, 11]
  end

  it 'should preserve attribute entries in the document header' do
    doc = reduce_file fixture_file 'parent-with-header-attributes.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Document Title
    :sectnums:
    :icons: font
    :toc:

    before include

    single line paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [6, 8, 10]
    (expect (doc.attr? 'sectnums')).to be true
    (expect (doc.attr? 'icons', 'font')).to be true
    (expect (doc.attr? 'toc')).to be true
  end

  it 'should use attribute defined in header when resolving include' do
    input_file = (fixture_file 'parent-with-include-with-attribute-reference-from-header.adoc')
    doc = reduce_file input_file
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title
    :chaptersdir: chapters

    == Chapter One

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
  end

  it 'should use attribute defined in body when resolving include' do
    doc = reduce_file fixture_file 'parent-with-include-with-attribute-reference-from-body.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
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
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 7
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 4, 7, 9, 13, 15]
  end

  it 'should use attribute defined inside preprocessor conditional header when resolving include' do
    input_file = fixture_file 'parent-with-include-with-attribute-reference-from-pp-conditional.adoc'
    doc = reduce_file input_file
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title
    :chaptersdir: chapters

    == Chapter One

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 4, 6]
  end

  it 'should use attribute passed to API when resolving include' do
    doc = reduce_file (fixture_file 'parent-with-include-with-attribute-reference-in-target.adoc'),
      attributes: 'chaptersdir=chapters'
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title

    == Chapter One

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should use attribute passed to API when resolving attribute value on include directive' do
    doc = reduce_file (fixture_file 'parent-with-include-with-attribute-reference-as-tag.adoc'), attributes: 'tag=body'
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    Start of body.

    End of body.

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 4
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7]
  end

  it 'should skip include when attribute in target cannot be resolved and attribute-missing=drop-line' do
    doc = nil
    with_memory_logger do |logger|
      input_file = fixture_file 'parent-with-include-with-attribute-reference-in-target.adoc'
      doc = reduce_file input_file, attributes: { 'attribute-missing' => 'drop-line' }
      messages = logger.messages
      (expect messages).to have_size 2
      (expect messages[1][:severity]).to eql :INFO
      (expect messages[1][:message][:text]).to include 'include dropped'
    end
    (expect doc.source_lines).to eql ['= Book Title']
    (expect doc.lineno).to eql 1
  end

  it 'should drop lines containing preprocessor directive when condition resolves to true' do
    doc = reduce_file (fixture_file 'parent-with-include-with-pp-conditional.adoc'), attributes: { 'flag' => '' }
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    primary content
    conditional content

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 6]
  end

  it 'should drop lines from start to end preprocessor directive when condition resolves to false' do
    doc = reduce_file fixture_file 'parent-with-include-with-pp-conditional.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    primary content

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should drop single line preprocessor conditional that resolves to false' do
    input_file = fixture_file 'parent-with-include-with-attribute-reference-from-pp-conditional.adoc'
    doc = reduce_file input_file, attributes: { 'chaptersdir' => 'chapters' }
    expected_lines = <<~'EOS'.chomp.split ?\n
    = Book Title

    == Chapter One

    content
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.find_by {|it| it.context != :document }
    (expect blocks).to have_size 3
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5]
  end

  it 'should reduce preprocessor conditional following a nested include' do
    doc = reduce_file (fixture_file 'parent-with-include-with-pp-conditionals-and-include.adoc'),
      attributes: { 'flag' => '' }
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    before nested include

    no includes here

    just good old-fashioned paragraph text

    after nested include

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    blocks = doc.blocks
    (expect blocks).to have_size 6
    (expect (blocks.map {|it| it.lineno })).to eql [1, 3, 5, 7, 9, 11]
  end

  it 'should resolve include inside true preprocessor conditional' do
    doc = reduce_file fixture_file 'parent-with-include-inside-true-pp-conditional.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    :flag:

    before include

    single line paragraph

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 3
    (expect (doc.blocks.map {|it| it.lineno })).to eql [3, 5, 7]
  end

  it 'should not resolve include inside false preprocessor conditional' do
    doc = reduce_file fixture_file 'parent-with-include-inside-false-pp-conditional.adoc'
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 3]
  end

  it 'should keep preprocessor conditional if :preserve_conditionals option is set' do
    doc = reduce_file (fixture_file 'parent-with-include-inside-false-pp-conditional.adoc'), preserve_conditionals: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    before include

    ifdef::no-such-attribute[]
    include::single-line-paragraph.adoc[]

    ifdef::backend[ignored]
    endif::[]
    after include
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 2
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1, 8]
  end

  it 'should keep single line preprocessor conditional if :preserve_conditionals option is set and no includes' do
    doc = reduce_file (fixture_file 'parent-with-single-line-preprocessor-conditional.adoc'),
      preserve_conditionals: true
    expected_lines = <<~'EOS'.chomp.split ?\n
    ifdef::asciidoctor-version[text]
    EOS
    (expect doc.source_lines).to eql expected_lines
    (expect doc.blocks).to have_size 1
    (expect (doc.blocks.map {|it| it.lineno })).to eql [1]
  end

  it 'should not log messages generated by document if null logger is specified' do
    with_memory_logger do |logger|
      silent_logger = Asciidoctor::NullLogger.new
      reduce_file (fixture_file 'document-with-warnings.adoc'), sourcemap: false, logger: silent_logger
      (expect logger.messages).to be_empty
      (expect Asciidoctor::LoggerManager.logger).to be silent_logger
    end
  end

  it 'should suppress log messages when reloading document' do
    with_memory_logger do |logger|
      reduce_file fixture_file 'parent-with-include-and-warning.adoc'
      messages = logger.messages
      (expect messages).to have_size 1
      (expect messages[0][:severity]).to eql :WARN
      (expect messages[0][:message][:text]).to include 'unterminated'
      (expect Asciidoctor::LoggerManager.logger).to be logger
    end
  end
end
