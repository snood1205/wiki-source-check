# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wikipedia::Client do
  let(:username) { 'Test User' }
  let(:client) { described_class.new username: }
  let(:title) { 'Ruby_(programming_language)' }
  let(:success_body) do
    {
      query: {
        pages: [
          { title:, revisions: [{ slots: { main: { content: 'wikitext content' } } }] }
        ]
      }
    }.to_json
  end

  describe '#initialize' do
    it 'builds the endpoint for the default language' do
      expect(client.api_endpoint).to eq 'https://en.wikipedia.org/w/api.php'
    end

    it 'builds the endpoint for an explicit language' do
      french_client = described_class.new username:, language: 'fr'

      expect(french_client.api_endpoint).to eq 'https://fr.wikipedia.org/w/api.php'
    end

    it 'uses the injected logger when one is given' do
      injected = Logger.new File::NULL

      expect(described_class.new(username:, logger: injected).logger).to equal injected
    end

    it 'falls back to the default logger when none is given' do
      expect(client.logger).to be_a Logger
    end
  end

  describe '#user_agent' do
    it 'underscores spaces in the username' do
      expect(client.user_agent).to include 'https://en.wikipedia.org/wiki/User:Test_User'
    end

    it 'includes the library version' do
      expect(client.user_agent).to include WikipediaSourceValidator::VERSION
    end

    it 'memoizes the built string' do
      expect(client.user_agent).to equal client.user_agent
    end
  end

  describe '#get_wikitext' do
    before do
      client.logger = Logger.new File::NULL

      stub_request(:get, client.api_endpoint)
        .with(query: hash_including(titles: title))
        .to_return(status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns the wikitext for the requested page' do
      expect(client.get_wikitext(title)).to eq 'wikitext content'
    end

    it 'requests the main slot revision content' do
      client.get_wikitext title

      expect(WebMock).to have_requested(:get, client.api_endpoint)
        .with(query: hash_including(prop: 'revisions', rvprop: 'content', rvslots: 'main'))
    end

    it 'sends the client user_agent' do
      client.get_wikitext title

      expect(WebMock).to have_requested(:get, client.api_endpoint)
        .with(query: hash_including(titles: title), headers: { 'User-Agent' => client.user_agent })
    end
  end

  describe '#get_wikitext when the page is missing' do
    before do
      stub_request(:get, client.api_endpoint)
        .with(query: hash_including(titles: title))
        .to_return(status: 404)
    end

    it 'propagates the not found exception' do
      expect { client.get_wikitext title }.to raise_error Wikipedia::Exceptions::NotFoundException
    end
  end
end
