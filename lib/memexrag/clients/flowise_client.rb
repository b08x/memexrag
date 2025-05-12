#!/usr/bin/env ruby
# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'json'

# This class provides an interface for interacting with the Flowise API.
class FlowiseApiClient
  # Initializes a new FlowiseApiClient instance.
  #
  # @param base_url [String] The base URL of the Flowise API.
  #
  # @return [void]
  def initialize(base_url)
    @base_url = base_url
    @conn = Faraday.new(url: @base_url) do |faraday|
      faraday.request :multipart
      faraday.request :json
      faraday.adapter Faraday.default_adapter
    end
  end

  # Sends a prediction request to the Flowise API.
  #
  # @param chatflow_id [String] The ID of the chatflow to use for prediction.
  # @param options [Hash] A hash of options for the prediction request.
  #   - :question [String] The question to ask the chatflow.
  #   - :history [Array] A list of previous questions and answers.
  #   - :overrideConfig [Hash] A hash of configuration overrides for the chatflow.
  #   - :socketIOClientId [String] The socket.io client ID.
  #   - :file_path [String] The path to a file to upload for prediction.
  #   - :worker_name [String] The name of the worker to use for prediction.
  #   - :worker_prompt [String] The prompt to use for the worker.
  #   - :prompt_values [Hash] A hash of prompt values to use for the worker.
  #
  # @return [Hash] The response from the Flowise API.
  def predict(chatflow_id, options = {})
    endpoint = "/api/v1/prediction/#{chatflow_id}"

    if options[:file_path]
      # File upload case
      payload = {
        files: Faraday::Multipart::FilePart.new(
          options[:file_path],
          'application/octet-stream',
          File.basename(options[:file_path])
        )
      }
      payload[:workerName] = options[:worker_name] if options[:worker_name]
      payload[:workerPrompt] = options[:worker_prompt] if options[:worker_prompt]
      payload[:promptValues] = options[:prompt_values].to_json if options[:prompt_values]

      response = @conn.post(endpoint) do |req|
        req.headers['Content-Type'] = 'multipart/form-data'
        req.body = payload
      end
    else
      # Simple JSON query case
      payload = options.slice(:question, :history, :overrideConfig, :socketIOClientId)

      response = @conn.post(endpoint) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = payload.to_json
      end
    end

    handle_response(response)
  end

  # Sends a document upsert request to the Flowise API.
  #
  # @param chatflow_id [String] The ID of the chatflow to use for document upsert.
  # @param file_path [String] The path to the file to upload.
  # @param local_ai_config [Hash] A hash of configuration options for the local AI.
  #   - :api_key [String] The API key for the local AI.
  #   - :base_path [String] The base path for the local AI.
  #   - :model_name [String] The name of the model to use for the local AI.
  #
  # @return [Hash] The response from the Flowise API.
  def upsert_document(chatflow_id, file_path, local_ai_config = {})
    endpoint = "/api/v1/vector/upsert/#{chatflow_id}"

    payload = {
      files: Faraday::Multipart::FilePart.new(
        file_path,
        'application/octet-stream',
        File.basename(file_path)
      ),
      localAIApiKey: local_ai_config[:api_key],
      basePath: local_ai_config[:base_path],
      modelName: local_ai_config[:model_name]
    }

    response = @conn.post(endpoint) do |req|
      req.headers['Content-Type'] = 'multipart/form-data'
      req.body = payload
    end

    handle_response(response)
  end

  private

  # Handles the response from the Flowise API.
  #
  # @param response [Faraday::Response] The response from the Flowise API.
  #
  # @return [Hash] The parsed response body.
  # @raise [RuntimeError] If the response status is not 200.
  def handle_response(response)
    case response.status
    when 200
      JSON.parse(response.body)
    else
      raise "Flowise API Error: #{response.status} - #{response.body}"
    end
  end
end

# TODO: assign chatflow_ids to names

# Example usage:
FlowiseApiClient.new('http://ninjabot.syncopated.net:3000')

# # For prediction with file upload
# result = client.predict('6aeba7f6-cefa-4fa2-9e8a-00c38094e4d5',
#   worker_name: 'example',
#   worker_prompt: 'example',
#   prompt_values: { key: 'val' },
#   file_path: '/home/user1/Desktop/example.pdf'
# )
# puts result

# For prediction with simple query
# query_result = client.predict(
#   '6aeba7f6-cefa-4fa2-9e8a-00c38094e4d5',
#   question: 'How to connect subjects to objects?'
# )
# puts query_result

# # For document upsert
# upsert_result = client.upsert_document('73406ff6-bf12-4c09-bd43-485ceb30b8ca',
#   '/home/b08x/Workspace/flowbots/flowbots.json',
#   {
#     base_path: 'http://192.168.36.3:8080/v1',
#     model_name: 'all-MiniLM-L6-v2'
#   }
# )
# puts upsert_result
