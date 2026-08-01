# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wikipedia::API do
  let(:client_class) do
    Class.new do
      include HTTParty
      include Wikipedia::API

      def initialize
        @api_endpoint = 'https://en.wikipedia.org/w/api.php'
      end

      def user_agent
        'TestAgent/1.0 (https://en.wikipedia.org/wiki/User:Test) test/1.0'
      end
    end
  end

  let(:client) { client_class.new }
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

  describe '#make_request' do
    before { client.logger = Logger.new(File::NULL) }

    context 'when the response is successful' do
      before do
        stub_request(:get, client.api_endpoint)
          .with(query: hash_including(action: 'query', titles: title, format: 'json', formatversion: '2'))
          .to_return(status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the parsed response body' do
        result = client.make_request title

        expect(result.dig('query', 'pages', 0, 'title')).to eq title
      end

      it 'sends the user_agent as the User-Agent header' do
        client.make_request title

        expect(WebMock).to have_requested(:get, client.api_endpoint)
          .with(query: hash_including(titles: title), headers: { 'User-Agent' => client.user_agent })
      end

      it 'merges additional params into the query' do
        client.make_request title, 0, rvprop: 'content'

        expect(WebMock).to have_requested(:get, client.api_endpoint)
          .with(query: hash_including(titles: title, rvprop: 'content'))
      end
    end

    context 'when the response is 429 once then succeeds' do
      before do
        stub_request(:get, client.api_endpoint)
          .with(query: hash_including(titles: title))
          .to_return(
            { status: 429, headers: { 'Retry-After' => '2' } },
            { status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' } }
          )

        allow(client).to receive(:sleep)
      end

      it 'retries the request and returns the successful response' do
        result = client.make_request title

        expect(result.dig('query', 'pages', 0, 'title')).to eq title
      end

      it 'sleeps for the retry-after duration before retrying' do
        client.make_request title

        expect(client).to have_received(:sleep).with(2)
      end

      it 'issues exactly two requests' do
        client.make_request title

        expect(WebMock).to have_requested(:get, client.api_endpoint)
          .with(query: hash_including(titles: title)).twice
      end

      it 'logs a warning about the rate limit' do
        allow(client.logger).to receive(:warn)

        client.make_request title

        expect(client.logger).to have_received(:warn).with(a_string_including("Access rate limited on [[#{title}]]"))
      end
    end

    context 'when the retry-after header is missing' do
      before do
        stub_request(:get, client.api_endpoint)
          .with(query: hash_including(titles: title))
          .to_return(
            { status: 429 },
            { status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' } }
          )

        allow(client).to receive(:sleep)
      end

      it 'falls back to a default wait time of 5 seconds' do
        client.make_request title

        expect(client).to have_received(:sleep).with(5)
      end
    end

    context 'when the response is 429 more than MAX_RETRIES times' do
      before do
        stub_request(:get, client.api_endpoint)
          .with(query: hash_including(titles: title))
          .to_return(status: 429, headers: { 'Retry-After' => '0' })

        allow(client).to receive(:sleep)
      end

      it 'raises Wikipedia::Exceptions::MaxRetriesException' do
        expect { client.make_request title }.to raise_error Wikipedia::Exceptions::MaxRetriesException
      end
    end

    context 'when the response is 404' do
      before do
        stub_request(:get, client.api_endpoint)
          .with(query: hash_including(titles: title))
          .to_return(status: 404)
      end

      it 'raises Wikipedia::Exceptions::NotFoundException' do
        expect { client.make_request title }.to raise_error Wikipedia::Exceptions::NotFoundException
      end
    end

    context 'when the response is 500' do
      before do
        stub_request(:get, client.api_endpoint)
          .with(query: hash_including(titles: title))
          .to_return(status: 500)
      end

      it 'raises Wikipedia::Exceptions::ServerError' do
        expect { client.make_request title }.to raise_error Wikipedia::Exceptions::ServerError
      end
    end

    context 'when the response is an unhandled status such as 403' do
      before do
        stub_request(:get, client.api_endpoint)
          .with(query: hash_including(titles: title))
          .to_return(status: 403)
      end

      it 'raises Wikipedia::Exceptions::UnexpectedResponseException rather than returning nil' do
        expect { client.make_request title }
          .to raise_error Wikipedia::Exceptions::UnexpectedResponseException, /403/
      end
    end
  end

  describe '#logger' do
    let(:error) do
      Wikipedia::Exceptions::ServerError.new('upstream exploded')
                                        .tap { |e| e.set_backtrace ['first_frame.rb:1', 'second_frame.rb:2'] }
    end

    # Memoize up front so the output matchers hold regardless of construction
    # order; they redirect the file descriptor rather than swapping $stderr.
    before { client.logger }

    it 'defaults to a Logger instance' do
      expect(client.logger).to be_a Logger
    end

    it 'writes to stderr by default' do
      expect { client.logger.warn 'a default logger message' }
        .to output(/a default logger message/).to_stderr_from_any_process
    end

    it 'memoizes the default logger' do
      expect(client.logger).to equal client.logger
    end

    it 'can be overridden via logger=' do
      custom_logger = Logger.new(File::NULL)

      client.logger = custom_logger

      expect(client.logger).to equal custom_logger
    end

    it 'repeats the severity prefix on every line of a multi-line message' do
      expect { client.logger.warn "first line\nsecond line" }
        .to output(/WARN -- : first line\n.*WARN -- : second line\n\z/).to_stderr_from_any_process
    end

    it 'leaves blank lines bare rather than emitting a prefix-only line' do
      expect { client.logger.warn "a\n\nb" }
        .to output(/WARN -- : a\n\n.*WARN -- : b\n\z/).to_stderr_from_any_process
    end

    it 'includes the class and backtrace when logging an exception' do
      expect { client.logger.error error }
        .to output(
          /upstream exploded \(Wikipedia::Exceptions::ServerError\)\n.*first_frame\.rb:1\n.*second_frame\.rb:2\n\z/
        ).to_stderr_from_any_process
    end

    it 'does not blow up on an exception with no backtrace' do
      expect { client.logger.error Wikipedia::Exceptions::NotFoundException.new('no page') }
        .to output(/no page \(Wikipedia::Exceptions::NotFoundException\)/).to_stderr_from_any_process
    end

    it 'inspects non-string, non-exception messages' do
      expect { client.logger.warn({ code: 429 }) }
        .to output(/WARN -- : \{.*429.*\}/).to_stderr_from_any_process
    end
  end

  describe '#extract_wikitext' do
    context 'when the response has the expected shape' do
      it 'returns the wikitext content' do
        response = { 'query' => { 'pages' => [{ 'revisions' => [{ 'slots' =>
                    { 'main' => { 'content' => 'wikitext content' } } }] }] } }

        expect(client.extract_wikitext(response)).to eq 'wikitext content'
      end
    end

    context 'when a key in the path is missing' do
      it 'returns nil' do
        response = { 'query' => { 'pages' => [] } }

        expect(client.extract_wikitext(response)).to be_nil
      end
    end
  end
end
