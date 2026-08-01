# frozen_string_literal: true

require 'httparty'
require_relative '../../wikipedia_source_validator'
require_relative 'api'

module Wikipedia
  # This is the main client for interacting with wikipedia. Practically everything goes through this.
  class Client
    include HTTParty
    include Wikipedia::API

    attr_reader :username

    def initialize(username:, language: 'en', logger: nil)
      @username = username
      @api_endpoint = "https://#{language}.wikipedia.org/w/api.php"
      @logger = logger
    end

    def user_agent
      return @user_agent if @user_agent

      version = WikipediaSourceValidator::VERSION
      url = "https://en.wikipedia.org/wiki/User:#{username.gsub(' ', '_')}"
      @user_agent = "WikipediaSourceValidator/#{version} (#{url}) wikipedia-source-validator/#{version}"
    end

    def get_wikitext(title)
      response = make_request title, prop: 'revisions', rvprop: 'content', rvslots: 'main'
      extract_wikitext response
    end
  end
end
