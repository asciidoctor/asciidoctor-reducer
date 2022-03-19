# frozen_string_literal: true

require_relative 'spec_helper'

describe Asciidoctor::Reducer::Extensions do
  describe_method '.group' do
    it 'should return extension group' do
      group = subject.call
      (expect group).to be_kind_of Proc
      doc = Asciidoctor.load []
      reg = (Asciidoctor::Extensions.create described_class.key, &group).activate doc
      (expect reg.preprocessors).to have_size 1
      (expect reg.treeprocessors).to have_size 1
    end
  end

  describe_method '.key' do
    it 'should return key for extension group' do
      (expect subject.call).to eql :reducer
    end
  end

  describe_method '.prepare_registry' do
    it 'should prepare a new registry if no registry is specified' do
      registry = subject.call
      (expect registry).not_to be_nil
      (expect registry.groups.keys).to have_size 1
      (expect registry.groups[described_class.key]).not_to be_nil
    end
  end

  describe_method '.register' do
    after { Asciidoctor::Extensions.unregister described_class.key if Asciidoctor::Extensions.groups }

    it 'should register extensions globally under group name' do
      subject.call
      (expect Asciidoctor::Extensions.groups).to have_key described_class.key
      doc = Asciidoctor.load []
      reg = Asciidoctor::Extensions::Registry.new.activate doc
      (expect reg.preprocessors).to have_size 1
      (expect reg.treeprocessors).to have_size 1
    end
  end

  describe_method '.unregister' do
    after { Asciidoctor::Extensions.unregister described_class.key if Asciidoctor::Extensions.groups }

    it 'should unregister extensions globally under group name' do
      Asciidoctor::Extensions.register described_class.key, &described_class.group
      (expect Asciidoctor::Extensions.groups).to have_key described_class.key
      subject.call
      (expect Asciidoctor::Extensions.groups).not_to have_key described_class.key
    end
  end
end
