# frozen_string_literal: true

require 'httparty'
require 'json'
require 'pathname'
require 'uri' # For URI()
require 'redis-client' # For Redis integration
require 'zip'          # For ZIP file handling
require 'tempfile'     # For Tempfile
require 'fileutils'    # For FileUtils.mkdir_p, FileUtils.remove_entry_secure (though not used for extraction dir)
require 'base64'       # For Base64.strict_decode64

module MemexRAG
  module Processors
    class DoclingConverter
      DEFAULT_CONVERSION_SERVICE_URL = ENV.fetch('CONVERSION_SERVICE_URL', 'http://localhost:8000').freeze
      DEFAULT_REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0').freeze
      DEFAULT_MAX_ATTEMPTS = 60
      DEFAULT_DELAY_SECONDS = 30

      attr_reader :conversion_service_url, :redis_url

      def initialize(conversion_service_url: nil, redis_url: nil)
        @conversion_service_url = conversion_service_url || DEFAULT_CONVERSION_SERVICE_URL
        @redis_url = redis_url || DEFAULT_REDIS_URL
        @redis = nil # Memoized client
      end

      def submit_file(file_path)
        endpoint = "#{@conversion_service_url}/convert/file"
        headers = { 'Accept' => 'application/json' }

        pn = Pathname.new(file_path)
        unless pn.exist? && pn.file?
          puts "File not found or is not a regular file: #{file_path}"
          return nil
        end

        body = { file: File.open(pn, 'rb') }

        puts "Uploading file: #{file_path} to #{endpoint}"
        begin
          response = HTTParty.post(endpoint, headers: headers, body: body, timeout: 60)

          if response.code == 202
            parsed_response = JSON.parse(response.body)
            puts "Task accepted. Task ID: #{parsed_response['task_id']}"
            # Ensure status_endpoint is just the path if that's what check_status expects
            status_endpoint_path = URI(parsed_response['status_endpoint']).path
            { task_id: parsed_response['task_id'], status_endpoint: status_endpoint_path }
          else
            puts "Error submitting task: #{response.code} - #{response.body}"
            nil
          end
        rescue HTTParty::Error, StandardError => e
          puts "Network or parsing error: #{e.message}"
          nil
        ensure
          body[:file].close if body && body[:file].respond_to?(:close) && !body[:file].closed?
        end
      end

      def check_status(status_endpoint_path, max_attempts: DEFAULT_MAX_ATTEMPTS, delay_seconds: DEFAULT_DELAY_SECONDS)
        status_url = "#{@conversion_service_url}#{status_endpoint_path}" # Assumes status_endpoint_path is like "/tasks/..."
        puts "Polling status at: #{status_url}"
        attempts = 0

        while attempts < max_attempts
          attempts += 1
          begin
            response = HTTParty.get(status_url, headers: { 'Accept' => 'application/json' }, timeout: 10) # Short timeout for status check

            if response.code == 200
              parsed_response = JSON.parse(response.body)
              status = parsed_response['status']&.upcase # Safe navigation and upcase
              api_result_data = parsed_response['result']
              api_error = parsed_response['error']
              api_traceback = parsed_response['traceback']

              puts "Attempt #{attempts}: Status = #{status}"

              case status
              when 'SUCCESS'
                puts 'Conversion successful according to API.'
                return { status: 'SUCCESS', data: api_result_data } # data contains 'data_key', etc.
              when 'FAILURE'
                puts "Conversion failed: #{api_error}"
                puts "Traceback: #{api_traceback}" if api_traceback
                return { status: 'FAILURE', error: api_error, traceback: api_traceback }
              when 'PENDING', 'STARTED', 'PROCESSING'
                sleep delay_seconds
              when 'ERROR' # From API's own internal errors during status check
                puts "API reported an error during status check: #{api_error}"
                return { status: 'FAILURE', error: "API error during status check: #{api_error}", traceback: api_traceback }
              else
                puts "Unknown API status received: #{status}. Full response: #{parsed_response.inspect}"
                return { status: 'UNKNOWN_API_STATUS', error: "Unknown API status: #{status}", data: parsed_response }
              end
            else
              puts "Error checking status (HTTP #{response.code}): #{response.body}"
              sleep delay_seconds # Wait before retrying on HTTP errors too
            end
          rescue HTTParty::Error, StandardError => e # Includes JSON::ParserError
            puts "Network or parsing error during polling: #{e.message}"
            sleep delay_seconds
          end
        end

        puts "Polling timed out after #{max_attempts} attempts."
        { status: 'TIMEOUT', error: 'Polling for conversion status timed out.' }
      end

      def retrieve_and_extract_zip_result(task_id) # Renamed arg for clarity, it IS the task_id/JID
        unless task_id && !task_id.strip.empty?
          puts 'Error: task_id is required for retrieving result.'
          return { status: 'FAILURE', error: 'task_id is required.' }
        end

        # This method constructs the key correctly using the task_id
        redis_key_for_zip = "conversion_result:#{task_id}"
        puts "Attempting to retrieve result from Redis with key: #{redis_key_for_zip}"
        # ... (rest of your retrieve_and_extract_zip_result method is fine)
        base64_string_from_redis = nil
        begin
          base64_string_from_redis = redis.call('GET', redis_key_for_zip)
        rescue StandardError => e
          puts "Error connecting to or fetching from Redis for key: #{redis_key_for_zip}. Error: #{e.message}"
          return { status: 'FAILURE', error: "Redis communication error: #{e.message}" }
        end

        unless base64_string_from_redis
          puts "Result not found in Redis for key: #{redis_key_for_zip}"
          return { status: 'FAILURE', error: "Result not found in Redis for key: #{redis_key_for_zip}" }
        end

        puts "Successfully fetched data from Redis for key: #{redis_key_for_zip}"
        decoded_zip_data = nil
        begin
          decoded_zip_data = Base64.strict_decode64(base64_string_from_redis)
          puts 'Base64 data decoded successfully.'
        rescue ArgumentError => e
          puts "Failed to decode Base64 data from Redis for key: #{redis_key_for_zip}. Error: #{e.message}"
          return { status: 'FAILURE', error: "Invalid Base64 data from Redis: #{e.message}" }
        end

        temp_zip_file = nil
        extraction_dir = nil

        begin
          temp_zip_file = Tempfile.new(['retrieved_output_', '.zip'], binmode: true)
          temp_zip_file.write(decoded_zip_data)
          temp_zip_file.close
          puts "Temporary ZIP file created at: #{temp_zip_file.path}"

          extraction_dir = Dir.mktmpdir("docling_extracted_#{task_id}") # Use task_id here too
          puts "Temporary extraction directory created at: #{extraction_dir}"

          begin
            Zip::File.open(temp_zip_file.path) do |zip_file|
              zip_file.each do |entry|
                entry_path = File.join(extraction_dir, entry.name)
                FileUtils.mkdir_p(File.dirname(entry_path)) unless File.directory?(File.dirname(entry_path))
                entry.extract(entry_path) { true }
              end
            end
            puts "Successfully extracted ZIP contents to: #{extraction_dir}"
            { status: 'SUCCESS', output_path: extraction_dir }
          rescue StandardError => e
            puts "Failed to extract ZIP file for key: #{redis_key_for_zip}. Error: #{e.message}"
            FileUtils.remove_entry_secure(extraction_dir) if extraction_dir && Dir.exist?(extraction_dir)
            { status: 'FAILURE', error: "ZIP extraction failed: #{e.message}" }
          end
        rescue StandardError => e
          puts "An unexpected error occurred during ZIP file operations for key: #{redis_key_for_zip}. Error: #{e.message}"
          FileUtils.remove_entry_secure(extraction_dir) if extraction_dir && Dir.exist?(extraction_dir)
          { status: 'FAILURE', error: "File operation error: #{e.message}" }
        ensure
          if temp_zip_file&.path && File.exist?(temp_zip_file.path)
            temp_zip_file.unlink
            puts "Temporary ZIP file #{temp_zip_file.path} unlinked."
          end
        end
      end

      # ... (store_extraction_results_as_json, determine_mime_type, binary_file?, redis methods as before) ...
      # def store_extraction_results_as_json(task_id, extraction_dir) # Changed arg for clarity
      #   files_data = []
      #   text_files_count = 0
      #   binary_files_count = 0

      #   Dir.glob(File.join(extraction_dir, '**', '*')).each do |file_path|
      #     next unless File.file?(file_path)

      #     relative_path = file_path.sub("#{extraction_dir}/", '')
      #     filename = File.basename(file_path)
      #     size = File.size(file_path)
      #     mime_type = determine_mime_type(file_path)
      #     is_binary = binary_file?(file_path, mime_type)

      #     content_data = if is_binary
      #                      binary_files_count += 1
      #                      Base64.strict_encode64(File.binread(file_path))
      #                    else
      #                      text_files_count += 1
      #                      begin
      #                        File.read(file_path, encoding: 'UTF-8')
      #                      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      #                        binary_files_count += 1 # Re-count as binary if fallback
      #                        text_files_count -= 1
      #                        Base64.strict_encode64(File.binread(file_path))
      #                      end
      #                    end

      #     files_data << {
      #       path: relative_path, filename: filename, mime_type: mime_type,
      #       size: size, is_binary: is_binary || (content_data.is_a?(String) && content_data.encoding == Encoding::ASCII_8BIT), # Refined is_binary check
      #       content: content_data
      #     }
      #   end

      #   json_data = {
      #     task_id: task_id, # Use task_id consistently
      #     extraction_timestamp: Time.now.utc.iso8601,
      #     files: files_data,
      #     metadata: {
      #       total_files: files_data.size, text_files: text_files_count,
      #       binary_files: binary_files_count, original_extraction_path: extraction_dir
      #     }
      #   }
      #   redis_key = "extraction_json:#{task_id}"
      #   begin
      #     redis.call('SET', redis_key, JSON.generate(json_data))
      #     redis.call('EXPIRE', redis_key, 86_400)
      #     { status: 'SUCCESS', redis_key: redis_key, file_count: files_data.size }
      #   rescue StandardError => e
      #     puts "Error storing extraction results in Redis: #{e.message}"
      #     { status: 'FAILURE', error: "Failed to store results in Redis: #{e.message}" }
      #   end
      # end

      def determine_mime_type(file_path)
        extension = File.extname(file_path).downcase
        case extension
        when '.txt' then 'text/plain'
        when '.md', '.markdown' then 'text/markdown'
        when '.html', '.htm' then 'text/html'
        when '.json' then 'application/json'
        when '.xml' then 'application/xml'
        when '.pdf' then 'application/pdf'
        when '.png' then 'image/png'
        when '.jpg', '.jpeg' then 'image/jpeg'
        when '.gif' then 'image/gif'
        when '.svg' then 'image/svg+xml'
        else 'application/octet-stream'
        end
      end

      def binary_file?(file_path, mime_type)
        return true if mime_type.start_with?('image/', 'audio/', 'video/') ||
                       ['application/pdf', 'application/octet-stream'].include?(mime_type)

        if mime_type.start_with?('text/')
          begin
            File.open(file_path, 'rb') { |f| return f.read(1024)&.include?("\x00") || false }
          rescue StandardError
            return true
          end
        end
        false
      end

      private

      def redis
        @redis = Redis.new(host: 'localhost', port: 6379, db: 0)
      end

      public # Make the orchestrator public if it's part of the class's API

      # New orchestrating method
      def process_file_and_get_extracted_contents(file_path, polling_options = {})
        submission_details = submit_file(file_path)
        return { status: 'SUBMISSION_FAILURE', error: 'Failed to submit file or obtain task_id.' } unless submission_details && submission_details[:task_id]

        task_id = submission_details[:task_id]
        status_endpoint = submission_details[:status_endpoint]

        puts "File submitted successfully. Task ID: #{task_id}. Polling status endpoint: #{status_endpoint}"

        # Merge any polling options passed in with defaults
        poll_max_attempts = polling_options[:max_attempts] || DEFAULT_MAX_ATTEMPTS
        poll_delay_seconds = polling_options[:delay_seconds] || DEFAULT_DELAY_SECONDS

        status_result = check_status(status_endpoint, max_attempts: poll_max_attempts, delay_seconds: poll_delay_seconds)

        unless status_result[:status] == 'SUCCESS'
          return { status: status_result[:status], error: status_result[:error] || 'Conversion polling did not result in SUCCESS.', details: status_result[:data] }
        end

        # status_result[:data] contains {"message"=>"...", "data_key"=>"conversion_result:...", ...}
        # The data_key is what we need for Redis, but retrieve_and_extract_zip_result constructs it from task_id
        puts "Conversion successful. API Data: #{status_result[:data].inspect}"
        puts "Proceeding to retrieve and extract ZIP using Task ID: #{task_id}"

        extraction_outcome = retrieve_and_extract_zip_result(task_id) # Pass the original task_id

        unless extraction_outcome[:status] == 'SUCCESS'
          # Clean up extraction_dir if retrieve_and_extract_zip_result failed and might have left it
          if extraction_outcome[:output_path] && Dir.exist?(extraction_outcome[:output_path])
            # FileUtils.remove_entry_secure(extraction_outcome[:output_path]) # retrieve_and_extract_zip_result should handle its own cleanup on failure
          end
          return { status: 'EXTRACTION_FAILURE', error: extraction_outcome[:error], task_id: task_id }
        end

        output_dir = extraction_outcome[:output_path]
        puts "ZIP content extracted to: #{output_dir}"

        # Optionally store contents as JSON in Redis
        # json_storage_outcome = store_extraction_results_as_json(task_id, output_dir)
        # puts "JSON storage outcome: #{json_storage_outcome.inspect}"
        # Remember to clean up the output_dir after processing if it's temporary and results are stored elsewhere
        # For now, we just return the path. The caller is responsible for cleanup if needed.

        { status: 'SUCCESS', task_id: task_id, extracted_output_path: output_dir, api_success_data: status_result[:data] }
      end
    end # for class DoclingConverter
  end # for module Processors
end # for module MemexRAG
