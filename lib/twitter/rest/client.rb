require 'base64'
require 'http'
require 'json'
require 'timeout'
require 'twitter/client'
require 'twitter/error'
require 'twitter/rest/api'

module Twitter
  module REST
    # Wrapper for the Twitter REST API
    #
    # @note All methods have been separated into modules and follow the same grouping used in {http://dev.twitter.com/doc the Twitter API Documentation}.
    # @see http://dev.twitter.com/pages/every_developer
    class Client < Twitter::Client
      include Twitter::REST::API
      attr_accessor :bearer_token
      attr_writer :connection_options, :middleware
      ENDPOINT = 'https://api.twitter.com'

      # Perform an HTTP GET request
      def get(path, params = {})
        header = auth_header(:get, path, params)
        request(:get, path, {:params => params}, :authorization => header)
      end

      # Perform an HTTP POST request
      def post(path, params = {})
        header = params.values.any? { |value| value.respond_to?(:to_io) } ? auth_header(:post, path, params, {}) : auth_header(:post, path, params)
        request(:post, path, {:form => params}, :authorization => header)
      end

      # @return [Boolean]
      def bearer_token?
        !!bearer_token
      end

      # @return [Boolean]
      def credentials?
        super || bearer_token?
      end

    private

      def request(method, path, params = {}, headers = {})
        response = HTTP.with(headers).send(method, ENDPOINT + path, params)
        error = error(response)
        fail(error) if error
        response.parse
      end

      def error(response)
        klass = Twitter::Error.errors[response.code]
        if klass == Twitter::Error::Forbidden
          forbidden_error(response)
        elsif !klass.nil?
          klass.from_response(response)
        end
      end

      def forbidden_error(response)
        error = Twitter::Error::Forbidden.from_response(response)
        klass = Twitter::Error.forbidden_messages[error.message]
        if klass
          klass.from_response(response)
        else
          error
        end
      end

      def auth_header(method, path, params = {}, signature_params = params)
        if !user_token?
          @bearer_token = token unless bearer_token?
          bearer_auth_header
        else
          oauth_auth_header(method, ENDPOINT + path, signature_params).to_s
        end
      end

      def bearer_auth_header
        token = bearer_token.is_a?(Twitter::Token) && bearer_token.bearer? ? bearer_token.access_token : bearer_token
        "Bearer #{token}"
      end
    end
  end
end
