# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wikipedia::Wikitext::RefParser do
  subject(:parser) { described_class.new wikitext }

  describe '#refs' do
    context 'when the wikitext has no ref tags' do
      let(:wikitext) { 'Ruby is a programming language.' }

      it 'returns an empty array' do
        expect(parser.refs).to be_empty
      end
    end

    context 'with a plain ref tag' do
      let(:wikitext) { 'Ruby was created in 1995.<ref>{{cite web|title=Ruby}}</ref>' }

      it 'extracts a single reference' do
        expect(parser.refs.size).to eq 1
      end

      it 'captures the content' do
        expect(parser.refs.first.content).to eq '{{cite web|title=Ruby}}'
      end

      it 'has no name' do
        expect(parser.refs.first).not_to be_named
      end

      it 'is not self closing' do
        expect(parser.refs.first).not_to be_self_closing
      end
    end

    context 'with a named ref tag' do
      let(:wikitext) { '<ref name="matz">Matsumoto 1995</ref>' }

      it 'captures the name' do
        expect(parser.refs.first.name).to eq 'matz'
      end

      it 'captures the content' do
        expect(parser.refs.first.content).to eq 'Matsumoto 1995'
      end

      it 'is named' do
        expect(parser.refs.first).to be_named
      end
    end

    context 'with a single quoted name' do
      let(:wikitext) { "<ref name='matz'>Matsumoto 1995</ref>" }

      it 'captures the name' do
        expect(parser.refs.first.name).to eq 'matz'
      end
    end

    context 'with an unquoted name' do
      let(:wikitext) { '<ref name=matz>Matsumoto 1995</ref>' }

      it 'captures the name' do
        expect(parser.refs.first.name).to eq 'matz'
      end
    end

    context 'with a self closing ref tag' do
      let(:wikitext) { 'Reused here.<ref name="matz" />' }

      it 'is self closing' do
        expect(parser.refs.first).to be_self_closing
      end

      it 'captures the name' do
        expect(parser.refs.first.name).to eq 'matz'
      end

      it 'has no content' do
        expect(parser.refs.first.content).to be_nil
      end
    end

    context 'with a self closing ref tag without a space before the slash' do
      let(:wikitext) { '<ref name="matz"/>' }

      it 'is self closing' do
        expect(parser.refs.first).to be_self_closing
      end

      it 'captures the name' do
        expect(parser.refs.first.name).to eq 'matz'
      end
    end

    context 'with a ref tag with a group' do
      let(:wikitext) { '<ref group="lower-alpha" name="note">A note</ref>' }

      it 'captures the group' do
        expect(parser.refs.first.group).to eq 'lower-alpha'
      end

      it 'captures the name alongside the group' do
        expect(parser.refs.first.name).to eq 'note'
      end

      it 'has (a) group' do
        expect(parser.refs.first.group?).to be true
      end
    end

    context 'with an ref tag without a group' do
      let(:wikitext) { '<ref>A source</ref>' }

      it 'does not have a group' do
        expect(parser.refs.first.group?).to be false
      end
    end

    context 'with uppercase tags' do
      let(:wikitext) { '<REF NAME="matz">Matsumoto</REF>' }

      it 'extracts the ref' do
        expect(parser.refs.size).to eq 1
      end

      it 'captures the name from the uppercase attribute' do
        expect(parser.refs.first.name).to eq 'matz'
      end
    end

    context 'with a multiline ref tag' do
      let(:wikitext) do
        <<~WIKITEXT
          Text here.<ref>{{cite book
            |title=Programming Ruby
            |year=2004
          }}</ref>
        WIKITEXT
      end

      it 'extracts the ref' do
        expect(parser.refs.size).to eq 1
      end

      it 'captures the full multi-line content' do
        expect(parser.refs.first.content).to include 'title=Programming Ruby'
      end
    end

    context 'with whitespace inside the closing tag' do
      let(:wikitext) { '<ref>A source</ref >' }

      it 'extracts the ref' do
        expect(parser.refs.size).to eq 1
      end
    end

    context 'with multiple ref tags' do
      let(:wikitext) do
        'One<ref name="a">First</ref> two<ref>Second</ref> three<ref name="a" />'
      end

      it 'extracts every ref' do
        expect(parser.refs.size).to eq 3
      end

      it 'preserves document order' do
        expect(parser.refs.map(&:content)).to eq ['First', 'Second', nil]
      end

      it 'records the offset of each ref' do
        expect(parser.refs.map(&:offset)).to eq [3, 32, 55]
      end
    end

    context 'with a ref tag inside an HTML comment' do
      let(:wikitext) { 'Real<ref>A source</ref> <!-- <ref>A commented out source</ref> -->' }

      it 'ignores the commented out ref' do
        expect(parser.refs.size).to eq 1
      end

      it 'extracts only the real ref' do
        expect(parser.refs.first.content).to eq 'A source'
      end
    end

    context 'with a multi-line comment containing ref tags' do
      let(:wikitext) do
        <<~WIKITEXT
          Real<ref>A source</ref>
          <!--
          <ref name="draft">Not ready yet</ref>
          <ref>Another draft</ref>
          -->
        WIKITEXT
      end

      it 'ignores every ref inside the comment' do
        expect(parser.refs.size).to eq 1
      end
    end

    context 'with a comment inside a ref tag' do
      let(:wikitext) { '<ref>A source<!-- an editor note --></ref>' }

      it 'still extracts the ref' do
        expect(parser.refs.size).to eq 1
      end

      it 'preserves the comment in the content' do
        expect(parser.refs.first.content).to eq 'A source<!-- an editor note -->'
      end
    end

    context 'with a ref tag inside nowiki' do
      let(:wikitext) { 'Real<ref>A source</ref> <nowiki><ref>Not a real ref</ref></nowiki>' }

      it 'ignores the ref inside nowiki' do
        expect(parser.refs.size).to eq 1
      end
    end

    context 'with a ref tag inside pre' do
      let(:wikitext) { 'Real<ref>A source</ref> <pre><ref>Not a real ref</ref></pre>' }

      it 'ignores the ref inside pre' do
        expect(parser.refs.size).to eq 1
      end
    end

    context 'with angle brackets that are not tags' do
      let(:wikitext) { 'A comparison of 3 < 5 and 10 > 2.<ref>A source</ref>' }

      it 'extracts the ref' do
        expect(parser.refs.size).to eq 1
      end
    end

    context 'with an ampersand in the ref content' do
      let(:wikitext) { '<ref>{{cite web|url=http://example.com/?a=1&b=2}}</ref>' }

      it 'preserves the ampersand rather than escaping it' do
        expect(parser.refs.first.content).to eq '{{cite web|url=http://example.com/?a=1&b=2}}'
      end
    end

    context 'with an angle bracket in the ref content' do
      let(:wikitext) { '<ref>The value a < b holds</ref>' }

      it 'preserves the bare angle bracket' do
        expect(parser.refs.first.content).to eq 'The value a < b holds'
      end
    end

    context 'with an empty ref tag' do
      let(:wikitext) { '<ref></ref>' }

      it 'captures empty content' do
        expect(parser.refs.first.content).to eq ''
      end
    end

    context 'with a self closing references container' do
      let(:wikitext) { 'Body<ref>A source</ref> <references />' }

      it 'does not treat the container as a ref' do
        expect(parser.refs.size).to eq 1
      end

      it 'extracts only the real ref' do
        expect(parser.refs.first.content).to eq 'A source'
      end
    end

    context 'with a references container carrying attributes' do
      let(:wikitext) { '<ref>A source</ref> <references group="lower-alpha" responsive="1" />' }

      it 'does not treat the container as a ref' do
        expect(parser.refs.size).to eq 1
      end
    end

    context 'with refs defined inside a references container' do
      let(:wikitext) { 'Body<ref name="a">A source</ref> <references><ref name="b">Defined here</ref></references>' }

      it 'extracts the inline ref and the list defined ref' do
        expect(parser.refs.map(&:name)).to eq %w[a b]
      end

      it 'does not swallow the list defined ref into the container' do
        expect(parser.refs.map(&:content)).to eq ['A source', 'Defined here']
      end
    end
  end

  describe '#unclosed' do
    context 'when every ref is closed' do
      let(:wikitext) { '<ref>A source</ref><ref name="a" />' }

      it 'is empty' do
        expect(parser.unclosed).to be_empty
      end
    end

    context 'with an unclosed ref tag' do
      let(:wikitext) { 'Text<ref>An unclosed source' }

      it 'reports the unclosed ref' do
        expect(parser.unclosed.size).to eq 1
      end

      it 'records where the unclosed ref started' do
        expect(parser.unclosed.first.offset).to eq 4
      end

      it 'captures the remaining text as content' do
        expect(parser.unclosed.first.content).to eq 'An unclosed source'
      end

      it 'does not include it among the well formed refs' do
        expect(parser.refs).to be_empty
      end
    end

    context 'with an unclosed named ref tag' do
      let(:wikitext) { 'Text<ref name="matz">An unclosed source' }

      it 'captures the name' do
        expect(parser.unclosed.first.name).to eq 'matz'
      end
    end

    context 'with a closed ref tag before an unclosed one' do
      let(:wikitext) { 'A<ref>Closed</ref> B<ref>Unclosed' }

      it 'still extracts the closed ref' do
        expect(parser.refs.map(&:content)).to eq ['Closed']
      end

      it 'reports the unclosed ref' do
        expect(parser.unclosed.map(&:content)).to eq ['Unclosed']
      end
    end
  end
end
