# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wikipedia::Wikitext::Document do
  subject(:document) { described_class.new wikitext }

  describe '#refs' do
    let(:wikitext) { 'A<ref>{{cite web|url=https://example.com}}</ref> B<ref name="b" />' }

    it 'extracts both refs' do
      expect(document.refs.size).to eq 2
    end
  end

  describe '#unclosed' do
    let(:wikitext) { 'A<ref>{{cite web|url=https://example.com}}</ref> B<ref>never closed' }

    it 'reports a ref whose tag was never closed' do
      expect(document.unclosed.size).to eq 1
    end

    # The extent of an unclosed ref is unknown, so anything after it is not ours to read.
    it 'does not read citations out of an unclosed ref' do
      expect(document.citations.size).to eq 1
    end
  end

  describe '#citations' do
    context 'when each ref holds one template' do
      let(:wikitext) { 'A<ref>{{cite web|url=https://example.com}}</ref> B<ref>{{cite book|title=B}}</ref>' }

      it 'returns one citation per template' do
        expect(document.citations.size).to eq 2
      end

      it 'orders them as they appear in the article' do
        expect(document.citations.map(&:name)).to eq ['Cite web', 'Cite book']
      end
    end

    # This specifically is allowed per [[WP:CITEBUNDLE]]
    context 'when one ref holds several templates, as a bundled citation does' do
      let(:wikitext) { '<ref>{{cite book|title=A}} and {{cite book|title=B}}</ref>' }

      it 'returns a citation for each of them' do
        expect(document.citations.size).to eq 2
      end

      it 'points all of them at the one ref' do
        expect(document.citations.map(&:ref).uniq.size).to eq 1
      end
    end

    context 'when a ref only reuses a name' do
      let(:wikitext) { '<ref name="a">{{cite book|title=A}}</ref><ref name="a" />' }

      it 'shows one citation' do
        expect(document.citations.size).to eq 1
      end
    end

    context 'when a template inside a ref is never closed' do
      let(:wikitext) { '<ref>{{cite web|title=A</ref> tail}} more' }

      it 'does not read a template that runs past the closing tag' do
        expect(document.citations).to be_empty
      end
    end

    context 'when a ref holds no template at all' do
      let(:wikitext) { '<ref>https://example.com</ref>' }

      it 'returns nothing' do
        expect(document.citations).to be_empty
      end
    end
  end

  # An offset is absolute and counted in bytes, since that is what StringScanner#pos reports.
  describe 'citation offsets' do
    context 'with a plain ref' do
      let(:wikitext) { 'Body text<ref>{{cite web|url=https://example.com}}</ref>' }

      it 'measures from the start of the article, not the start of the ref' do
        expect(document.citations.first.offset).to eq wikitext.byteindex('{{cite web')
      end
    end

    context 'with attributes widening the opening tag' do
      let(:wikitext) { 'Body<ref name="long attribute here">{{cite book|title=A}}</ref>' }

      it 'skips past the attributes' do
        expect(document.citations.first.offset).to eq wikitext.byteindex('{{cite book')
      end
    end

    # This is relevant as non-ASCII text has a larger byte size
    context 'with non-ASCII text before the ref' do
      let(:wikitext) { "Café ''Malus doméstica''<ref>{{cite web|url=https://example.com}}</ref>" }

      it 'lands on the template' do
        citation = document.citations.first

        expect(wikitext.byteslice(citation.offset, 10)).to eq '{{cite web'
      end

      it 'still finds the citation' do
        expect(document.citations.size).to eq 1
      end
    end

    context 'with non-ASCII text inside the ref attributes' do
      let(:wikitext) { '<ref name="café">{{cite book|title=A}}</ref>' }

      it 'lands on the template' do
        expect(document.citations.first.offset).to eq wikitext.byteindex('{{cite book')
      end
    end
  end

  describe '#definitions' do
    let(:wikitext) { '<ref name="a">A</ref><ref name="a" /><ref>anonymous</ref>' }

    it 'treats a ref with content as a definition' do
      expect(document.definitions.size).to eq 2
    end
  end

  describe '#uses' do
    let(:wikitext) { '<ref name="a">A</ref><ref name="a" /><ref>anonymous</ref>' }

    it 'treats a self closing ref as a use' do
      expect(document.uses.size).to eq 1
    end
  end

  describe '#definitions_by_name' do
    let(:wikitext) { '<ref name="a">First</ref><ref name="b">Second</ref><ref>anonymous</ref>' }

    it 'contains each ref name in keys' do
      expect(document.definitions_by_name.keys).to eq %w[a b]
    end

    it 'leaves out anonymous refs' do
      expect(document.definitions_by_name.values.flatten.size).to eq 2
    end

    context 'when one name is defined twice' do
      let(:wikitext) { '<ref name="a">First</ref><ref name="a">Second</ref>' }

      it 'keeps both to later alert the user' do
        expect(document.definitions_by_name['a'].size).to eq 2
      end
    end
  end

  describe '#uses_by_name' do
    let(:wikitext) { '<ref name="a">A</ref><ref name="a" /><ref name="a" /><ref name="orphan" />' }

    it 'collects every reuse of a name' do
      expect(document.uses_by_name['a'].size).to eq 2
    end

    it 'records a reuse even when nothing defines the name' do
      expect(document.uses_by_name).to have_key 'orphan'
    end
  end

  describe '#orphans' do
    let(:wikitext) { '<ref name="a">A</ref><ref name="a" /><ref name="a" /><ref name="orphan" />' }

    it 'identifies a name that is used but never defined' do
      expect(document.orphans).to eq %w[orphan]
    end
  end

  describe '#untemplated' do
    let(:wikitext) do
      <<~WIKITEXT
        <ref>{{cite web|url=https://example.com}}</ref> \
          <ref>https://example.com/no-template</ref> \
          <ref>Koch, John. ''Celtic Culture'', ABC-CLIO 2006, p. 146.</ref>
      WIKITEXT
    end

    it 'returns every ref without a template' do
      expect(document.untemplated.size).to eq 2
    end

    it 'includes a ref that is only a url' do
      expect(document.untemplated.first.content).to eq 'https://example.com/no-template'
    end

    it 'includes a ref that is text' do
      expect(document.untemplated[1].content).to eq "Koch, John. ''Celtic Culture'', ABC-CLIO 2006, p. 146."
    end

    it 'leaves out refs that carry a citation template' do
      expect(document.untemplated.map(&:content)).not_to include a_string_including('cite web')
    end
  end

  describe 'an article with no references' do
    let(:wikitext) { 'No references at all.' }

    it 'reports no refs' do
      expect(document.refs).to be_empty
    end

    it 'reports no citations' do
      expect(document.citations).to be_empty
    end

    it 'reports nothing untemplated' do
      expect(document.untemplated).to be_empty
    end
  end
end
