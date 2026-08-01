# frozen_string_literal: true

require 'logger'
require_relative 'exceptions/max_retries_exception'
require_relative 'exceptions/not_found_exception'
require_relative 'exceptions/server_error'
require_relative 'exceptions/unexpected_response_exception'

module Wikipedia
  # The main module for interacting with the Wikipedia API
  module API
    attr_reader :api_endpoint
    attr_writer :logger

    MAX_RETRIES = 3

    # Mirrors Logger's default format, but repeats the prefix on every line
    LOG_FORMATTER = proc do |severity, datetime, progname, message|
      # Format is 1970-01-01T00:00:00.000000
      timestamp = datetime.strftime '%Y-%m-%dT%H:%M:%S.%6N'
      prefix = "#{severity[0]}, [#{timestamp} ##{Process.pid}] #{severity.rjust(5)} -- #{progname}: "

      body = case message
             when ::String then message
             when ::Exception then "#{message.message} (#{message.class})\n#{(message.backtrace || []).join("\n")}"
             else message.inspect
             end

      body.chomp.lines.map { |line| line.chomp.empty? ? "\n" : "#{prefix}#{line.chomp}\n" }.join
    end

    def logger
      @logger ||= Logger.new($stderr, formatter: LOG_FORMATTER)
    end

    def make_request(title, retries = 0, **additional_params)
      query = params title, additional_params
      response = self.class.get(api_endpoint, query:, headers: { 'User-Agent': user_agent })

      handle_response response, title, retries, additional_params
    end

    def extract_wikitext(response)
      response.dig 'query', 'pages', 0, 'revisions', 0, 'slots', 'main', 'content'
    end

    private

    def params(title, additional_params)
      { action: 'query', titles: title, format: 'json', formatversion: '2' }.merge(additional_params)
    end

    def handle_response(response, title, retries, additional_params)
      case response.code
      when 200 then response.parsed_response
      when 429 then handle429 response, title, retries, additional_params
      when 404 then raise Exceptions::NotFoundException, "Wikipedia has no page at [[#{title}]]"
      when 500..599 then raise Exceptions::ServerError, "Wikipedia returned #{response.code} for [[#{title}]]"
      else raise Exceptions::UnexpectedResponseException,
                 "Wikipedia returned an unhandled #{response.code} for [[#{title}]]"
      end
    end

    def handle429(response, title, retries, additional_params)
      raise Exceptions::MaxRetriesException if retries >= MAX_RETRIES

      retry_after = response.headers['retry-after']&.to_i || 5

      logger.warn <<~WARNING
        Access rate limited on [[#{title}]]...
        Waiting #{retry_after} seconds before retrying...
      WARNING

      sleep retry_after

      make_request title, retries + 1, **additional_params
    end
  end
end
