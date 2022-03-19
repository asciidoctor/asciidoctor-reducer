# frozen_string_literal: true

require 'asciidoctor/reducer/include_mapper/extension'

describe Asciidoctor::Reducer::IncludeMapper do
  it 'should not add include mapping comment if document has no includes' do
    ext_class = described_class
    doc = run_scenario do
      input_source <<~'END'
      no includes here

      not a single one
      END

      reduce_options extensions: proc { tree_processor ext_class unless document.options[:reduced] }
    end
    (expect doc.source_lines[-1]).to eql 'not a single one'
  end

  it 'should not add include mapping comment if document only has partial includes' do
    ext_class = described_class
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::include-with-tag.adoc[tag=body]

      after include
      END

      reduce_options extensions: proc { tree_processor ext_class unless document.options[:reduced] }
    end
    (expect doc.source_lines[-1]).to eql 'after include'
  end

  it 'should add include mapping comment to bottom of reduced file' do
    ext_class = described_class
    include_file = nil
    doc = run_scenario do
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

      reduce_options extensions: proc { tree_processor ext_class unless document.options[:reduced] }
    end
    (expect doc.source_lines[-1]).to eql %(//# includes=#{File.basename include_file, '.adoc'},no-includes)
  end

  it 'should only add entries to include mapping comment that are included fully' do
    ext_class = described_class
    doc = run_scenario do
      input_source <<~'END'
      beginning

      include::single-line-paragraph.adoc[]

      include::include-with-tag.adoc[tag=body]

      end
      END

      reduce_options extensions: proc { tree_processor ext_class unless document.options[:reduced] }
    end
    (expect doc.source_lines[-1]).to eql '//# includes=single-line-paragraph'
  end

  it 'should load includes from mapping comment' do
    ext_class = described_class
    result = StringIO.new
    doc = Asciidoctor.convert <<~'END', to_file: result, extensions: proc { tree_processor ext_class }
    see xref:no-includes.adoc#sectid[]

    [#sectid]
    == Target Section

    //# includes=include-with-include,no-includes
    END
    includes = doc.catalog[:includes]
    (expect includes).to have_size 2
    (expect includes['include-with-include']).to be true
    (expect includes['no-includes']).to be true
    (expect result.string).to include '<a href="#sectid">Target Section</a>'
  end

  it 'should not load includes if mapping comment is missing' do
    ext_class = described_class
    result = StringIO.new
    doc = Asciidoctor.convert <<~'END', to_file: result, extensions: proc { tree_processor ext_class }
    see xref:no-includes.adoc#sectid[]

    [#sectid]
    == Target Section
    END
    (expect doc.catalog[:includes]).to be_empty
    (expect result.string).to include '<a href="no-includes.html#sectid">no-includes.html</a>'
  end

  it 'should not load includes if document is empty' do
    ext_class = described_class
    doc = Asciidoctor.load '', extensions: proc { tree_processor ext_class }
    (expect doc.catalog[:includes]).to be_empty
  end

  it 'should register include mapper extension globally when asciidoctor/reducer/include_mapper is required' do
    groups_size = Asciidoctor::Extensions.groups.size
    (expect require 'asciidoctor/reducer/include_mapper').not_to be_nil
    (expect Asciidoctor::Extensions.groups.size).to be > groups_size
    doc = run_scenario do
      input_source <<~'END'
      before include

      include::no-includes.adoc[]

      after include
      END
    end
    (expect doc.source_lines[-1]).to eql '//# includes=no-includes'
  ensure
    Asciidoctor::Extensions.unregister Asciidoctor::Extensions.groups.keys.last
  end
end
