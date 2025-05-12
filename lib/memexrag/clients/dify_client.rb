# memexrag/clients/dify_client.rb
# frozen_string_literal: true

require 'httparty'
require 'json'

module MemexRAG
  module Clients
    class DifyClient
      # Custom Error classes for DifyClient
      class DifyError < StandardError; end
      class DifyConfigurationError < DifyError; end

      class DifyApiError < DifyError
        attr_reader :status_code, :response_body

        def initialize(message, status_code = nil, response_body = nil)
          super(message)
          @status_code = status_code
          @response_body = response_body
        end
      end

      attr_reader :base_url, :api_key, :default_workflow_id

      # Initializes the Dify client.
      # Configuration is expected to be in ENV variables.
      #
      # @param base_url [String] Base URL for the Dify API (e.g., "http://crambot/v1").
      # @param api_key [String] Your Dify API key.
      # @param default_workflow_id [String, nil] An optional default workflow ID.
      def initialize(base_url: ENV.fetch('DIFY_BASE_URL', nil),
                     api_key: ENV.fetch('DIFY_API_KEY', nil),
                     default_workflow_id: ENV.fetch('DIFY_DEFAULT_WORKFLOW_ID', nil)) # DIFY_DEFAULT_WORKFLOW_ID can be blank
        @base_url = base_url
        @api_key = api_key
        @default_workflow_id = default_workflow_id

        raise DifyConfigurationError, 'Dify base URL (DIFY_BASE_URL) is not configured.' unless @base_url && !@base_url.strip.empty?
        raise DifyConfigurationError, 'Dify API key (DIFY_API_KEY) is not configured.' unless @api_key && !@api_key.strip.empty?

        @base_url = @base_url.chomp('/')
      end

      # Executes a Dify workflow and streams the response.
      #
      # @param inputs [Hash] The inputs for the Dify workflow.
      # @param user_id [String] The user identifier for the Dify request.
      # @param workflow_id [String, nil] The specific workflow ID to run. Defaults to `default_workflow_id`.
      # @param response_mode [String] Typically "streaming".
      # @param timeout [Integer] HTTP timeout in seconds.
      # @yield [String] Yields each chunk of the SSE stream from Dify.
      # @raise [DifyConfigurationError] if workflow_id is not available.
      # @raise [DifyApiError] for API-related errors.
      # @raise [HTTParty::Error, SocketError, etc.] for network errors.
      def execute_workflow_streaming(inputs:, user_id:, workflow_id: nil, response_mode: 'streaming', timeout: 300)
        target_workflow_id = workflow_id || @default_workflow_id
        api_url = if target_workflow_id && !target_workflow_id.strip.empty?
                    "#{@base_url}/workflows/#{target_workflow_id}/run"
                  elsif target_workflow_id && !target_workflow_id.strip.empty?
                    # If DIFY_BASE_URL is the *full* endpoint (e.g., http://crambot/v1/workflows/run)
                    # then target_workflow_id might not be needed in the path.
                    # The current logic assumes workflow_id is part of the path.
                    # If your DIFY_BASE_URL is already the full '.../run' endpoint,
                    # then this check and the URL construction needs adjustment.
                    # For now, assuming workflow_id is distinct.
                    # If DIFY_BASE_URL is 'http://crambot/v1/workflows/run', then set DIFY_DEFAULT_WORKFLOW_ID to "" or nil in .env
                    # and adjust URL construction.
                    # Given the previous logs and working curl, the endpoint is '.../workflows/run'.
                    # Let's assume if target_workflow_id is empty, base_url is the full path.
                    "#{@base_url}/workflows/#{target_workflow_id}/run"
                  else
                    # This case implies DIFY_BASE_URL is the full endpoint like "http://crambot/v1/workflows/run"
                    # Ensure your ENV['DIFY_BASE_URL'] is set to this full path if DIFY_DEFAULT_WORKFLOW_ID is empty.
                    @base_url
                  end

        headers = {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json',
          'Accept' => 'text/event-stream'
        }

        body = {
          'inputs' => inputs,
          'response_mode' => response_mode,
          'user' => user_id
        }.to_json

        logger.info "DifyClient: Sending request to #{api_url} for user #{user_id}"
        # logger.debug "DifyClient: Request body: #{body}" # Careful with sensitive data

        # HTTParty options, including debug if needed
        # httparty_options = { debug_output: $stderr } # Very verbose
        httparty_options = {}

        begin
          response_obj = HTTParty.post(
            api_url,
            headers: headers,
            body: body,
            stream_body: true,
            timeout: timeout,
            **httparty_options
          ) do |fragment, _request_proxy, net_http_response|
            # Ensure net_http_response is available
            unless net_http_response
              # This should ideally be caught by HTTParty::Error for connection failures
              # but as a safeguard if the block is somehow entered with a nil response.
              logger.error "DifyClient: CRITICAL - net_http_response is nil in streaming block. URL: #{api_url}"
              raise DifyApiError.new('Connection to Dify service failed: No HTTP response object received.', nil, nil)
            end

            status_code = net_http_response.code.to_i
            unless (200..299).cover?(status_code)
              logger.error "DifyClient: API error during stream. Status: #{status_code}. Fragment: #{fragment.inspect}. URL: #{api_url}"
              # Attempt to parse error from fragment if possible, though fragment might not be JSON error
              raise DifyApiError.new("Dify API request failed during stream with status #{status_code}", status_code, fragment)
            end

            yield fragment if block_given?
          end # HTTParty.post block

          # After streaming, check the overall response object from HTTParty if needed,
          # though errors during streaming should be caught above.
          if response_obj && !(200..299).cover?(response_obj.code.to_i)
            logger.error "DifyClient: API request completed with error status after stream: #{response_obj.code}. Body: #{response_obj.body}"
            raise DifyApiError.new("Dify API request finished with error status #{response_obj.code}", response_obj.code, response_obj.body)
          end
        rescue HTTParty::Error, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
          logger.error "DifyClient: Network/HTTP error connecting to Dify. URL: #{api_url}. Error: #{e.class} - #{e.message}"
          raise DifyError, "Network error while connecting to Dify: #{e.message}" # Re-raise as a DifyError or specific network error
        rescue DifyApiError => e # Re-raise DifyApiErrors caught during streaming
          raise e
        rescue StandardError => e
          logger.error "DifyClient: Unexpected error. URL: #{api_url}. Error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
          raise DifyError, "An unexpected error occurred: #{e.message}"
        end
      end
    end
  end
end
