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
      DEFAULT_MAX_ATTEMPTS = 10
      DEFAULT_DELAY_SECONDS = 5

      attr_reader :conversion_service_url, :redis_url

      def initialize(conversion_service_url: nil, redis_url: nil)
        @conversion_service_url = conversion_service_url || DEFAULT_CONVERSION_SERVICE_URL
        @redis_url = redis_url || DEFAULT_REDIS_URL
        @redis_client = nil # Memoized client
      end

      def submit_file(file_path)
        endpoint = "#{@conversion_service_url}/convert/file"
        headers = { 'Accept' => 'application/json' }

        pn = Pathname.new(file_path)
        unless pn.exist? && pn.file?
          puts "File not found or is not a regular file: #{file_path}"
          return nil # Keep original return type for this case
        end

        body = { file: File.open(pn, 'rb') }

        puts "Uploading file: #{file_path} to #{endpoint}"
        begin
          response = HTTParty.post(endpoint, headers: headers, body: body, timeout: 60)

          if response.code == 202
            parsed_response = JSON.parse(response.body)
            puts "Task accepted. Task ID: #{parsed_response['task_id']}"
            status_endpoint_path = URI(parsed_response['status_endpoint']).path
            # Return hash as before
            { task_id: parsed_response['task_id'], status_endpoint: status_endpoint_path }
          else
            puts "Error submitting task: #{response.code} - #{response.body}"
            nil # Keep original return type
          end
        rescue HTTParty::Error, StandardError => e
          puts "Network or parsing error: #{e.message}"
          nil # Keep original return type
        ensure
          body[:file].close if body && body[:file].respond_to?(:close) && !body[:file].closed?
        end
      end

      def check_status(status_endpoint_path, max_attempts: DEFAULT_MAX_ATTEMPTS, delay_seconds: DEFAULT_DELAY_SECONDS)
        status_url = "#{@conversion_service_url}#{status_endpoint_path}"
        puts "Polling status at: #{status_url}"
        attempts = 0

        while attempts < max_attempts
          attempts += 1
          begin
            response = HTTParty.get(status_url, headers: { 'Accept' => 'application/json' }, timeout: 10)

            if response.code == 200
              parsed_response = JSON.parse(response.body)
              status = parsed_response['status']
              puts "Attempt #{attempts}: Status = #{status}"

              case status
              when 'SUCCESS'
                puts 'Conversion successful.'
                # Return structure includes original 'result' which now contains sidekiq_jid
                return { status: 'SUCCESS', data: parsed_response['result'] }
              when 'FAILURE'
                puts "Conversion failed: #{parsed_response['error']}"
                puts "Traceback: #{parsed_response['traceback']}" if parsed_response['traceback']
                return { status: 'FAILURE', error: parsed_response['error'], traceback: parsed_response['traceback'] }
              when 'PENDING', 'STARTED'
                sleep delay_seconds
              else # for case
                puts "Unknown status: #{status}"
                return { status: 'UNKNOWN', data: parsed_response }
              end # for case
            else # for if response.code == 200
              puts "Error checking status: #{response.code} - #{response.body}"
              sleep delay_seconds
            end # for if
          rescue HTTParty::Error, StandardError => e
            puts "Network or parsing error during polling: #{e.message}"
            sleep delay_seconds
          end # for begin
        end # for while

        puts "Polling timed out after #{max_attempts} attempts."
        { status: 'TIMEOUT' } # Return hash as before
      end

      def retrieve_and_extract_zip_result(sidekiq_jid)
        unless sidekiq_jid && !sidekiq_jid.strip.empty?
          puts 'Error: sidekiq_jid is required for retrieving result.'
          return { status: 'FAILURE', error: 'sidekiq_jid is required.' }
        end

        redis_key = "conversion_result:#{sidekiq_jid}"
        puts "Attempting to retrieve result from Redis with key: #{redis_key}"
        base64_string_from_redis = nil
        begin
          base64_string_from_redis = redis.call('GET', redis_key)
        rescue StandardError => e # Catch Redis connection errors etc.
          puts "Error connecting to or fetching from Redis for key: #{redis_key}. Error: #{e.message}"
          return { status: 'FAILURE', error: "Redis communication error: #{e.message}" }
        end

        unless base64_string_from_redis
          puts "Result not found in Redis for key: #{redis_key}"
          return { status: 'FAILURE', error: "Result not found in Redis for key: #{redis_key}" }
        end

        puts "Successfully fetched data from Redis for key: #{redis_key}"
        decoded_zip_data = nil
        begin
          decoded_zip_data = Base64.strict_decode64(base64_string_from_redis)
          puts 'Base64 data decoded successfully.'
        rescue ArgumentError => e
          puts "Failed to decode Base64 data from Redis for key: #{redis_key}. Error: #{e.message}"
          return { status: 'FAILURE', error: "Invalid Base64 data from Redis: #{e.message}" }
        end

        temp_zip_file = nil
        extraction_dir = nil

        begin
          temp_zip_file = Tempfile.new(['retrieved_output_', '.zip'], binmode: true)
          temp_zip_file.write(decoded_zip_data)
          temp_zip_file.close # Close before Zip::File opens it by path
          puts "Temporary ZIP file created at: #{temp_zip_file.path}"

          extraction_dir = Dir.mktmpdir("docling_extracted_#{sidekiq_jid}")
          puts "Temporary extraction directory created at: #{extraction_dir}"

          begin
            Zip::File.open(temp_zip_file.path) do |zip_file|
              zip_file.each do |entry|
                entry_path = File.join(extraction_dir, entry.name)
                # Ensure parent directory exists before extraction
                FileUtils.mkdir_p(File.dirname(entry_path)) unless File.directory?(File.dirname(entry_path))
                entry.extract(entry_path) { true } # Allow overwrite if entry already exists
              end
            end
            puts "Successfully extracted ZIP contents to: #{extraction_dir}"
            { status: 'SUCCESS', output_path: extraction_dir }
          rescue StandardError => e
            puts "Failed to extract ZIP file for key: #{redis_key}. Error: #{e.message}"
            # Clean up extraction_dir if zip extraction fails partially or fully
            FileUtils.remove_entry_secure(extraction_dir) if extraction_dir && Dir.exist?(extraction_dir)
            { status: 'FAILURE', error: "ZIP extraction failed: #{e.message}" }
          end
        rescue StandardError => e
          puts "An unexpected error occurred during ZIP file operations for key: #{redis_key}. Error: #{e.message}"
          # Clean up extraction_dir if created before error
          FileUtils.remove_entry_secure(extraction_dir) if extraction_dir && Dir.exist?(extraction_dir)
          { status: 'FAILURE', error: "File operation error: #{e.message}" }
        ensure
          # Clean up the temporary ZIP file
          if temp_zip_file&.path && File.exist?(temp_zip_file.path)
            temp_zip_file.unlink 
            puts "Temporary ZIP file #{temp_zip_file.path} unlinked."
          end
          # Note: extraction_dir is intentionally not cleaned up on success here,
          # as its path is the successful result. It's cleaned up on Zip::Error or other StandardError.
        end
      end

      private

      def redis
        @redis_client ||= RedisClient.config(url: @redis_url).new_client
      end
    end # for class DoclingConverter
  end # for module Processors
end # for module MemexRAG
