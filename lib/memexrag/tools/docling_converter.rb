# frozen_string_literal: true

# Assuming RubyLLM::Tool is defined elsewhere and MemexRAG::Processors::DoclingConverter
# is the class we worked on previously (and is loaded/required).

class DoclingConverter < RubyLLM::Tool
  description 'Converts documents (primarily PDFs) into processable formats using the DoclingConverter service. Handles the entire conversion process including submission, status checking, and result retrieval.'

  param :file_path,
        type: :string,
        desc: 'The path to the file to be converted.',
        required: true

  param :max_attempts,
        type: :integer,
        desc: 'Maximum number of polling attempts for status checking. Defaults to the underlying processor\'s default.',
        required: false

  param :delay_seconds,
        type: :integer,
        desc: 'Delay between polling attempts in seconds. Defaults to the underlying processor\'s default.',
        required: false

  param :conversion_service_url,
        type: :string,
        desc: 'URL of the conversion service. Defaults to environment variable or http://localhost:8000.',
        required: false

  param :redis_url,
        type: :string,
        desc: 'URL of the Redis server. Defaults to environment variable or redis://localhost:6379/0.',
        required: false

  def initialize
    super
    begin
      # Create a base DoclingConverter processor instance.
      # It will use its own defaults if specific URLs are not provided here.
      @base_converter = MemexRAG::Processors::DoclingConverter.new(
        conversion_service_url: nil, # Let the processor handle its default
        redis_url: nil # Let the processor handle its default
      )
    rescue LoadError => e
      # This can happen if MemexRAG::Processors::DoclingConverter is not found
      @initialization_error = { error: "Failed to load MemexRAG::Processors::DoclingConverter. Is it required correctly? Details: #{e.message}" }
    rescue StandardError => e
      @initialization_error = { error: "Failed to initialize DoclingConverter processor. Details: #{e.message}" }
    end
  end

  def execute(file_path:, max_attempts: nil, delay_seconds: nil, conversion_service_url: nil, redis_url: nil)
    return @initialization_error if @initialization_error

    # Determine which converter instance to use for this execution.
    # If specific URLs are passed to execute, create a new instance for this call.
    # Otherwise, use the base_converter initialized earlier.
    current_converter = if conversion_service_url || redis_url
                          MemexRAG::Processors::DoclingConverter.new(
                            conversion_service_url: conversion_service_url, # Pass through, processor handles defaults
                            redis_url: redis_url # Pass through, processor handles defaults
                          )
                        else
                          @base_converter
                        end

    # 1. Submit the file for conversion
    submission_result = current_converter.submit_file(file_path)
    unless submission_result && submission_result[:task_id] && submission_result[:status_endpoint]
      error_message = 'Failed to submit file for conversion or received invalid response from submission.'
      details = submission_result || 'No submission result received.'
      puts "[TOOL ERROR] #{error_message} Details: #{details.inspect}"
      return { status: 'FAILURE', error: error_message, details: details }
    end

    task_id_from_submission = submission_result[:task_id] # This is the key ID we need throughout!
    status_endpoint = submission_result[:status_endpoint]
    puts "[TOOL INFO] File submitted. Task ID: #{task_id_from_submission}, Status Endpoint: #{status_endpoint}"

    # 2. Check the status of the conversion
    # Use provided polling params or fall back to the processor's defaults
    effective_max_attempts = max_attempts || MemexRAG::Processors::DoclingConverter::DEFAULT_MAX_ATTEMPTS
    effective_delay_seconds = delay_seconds || MemexRAG::Processors::DoclingConverter::DEFAULT_DELAY_SECONDS

    puts "[TOOL INFO] Polling status with max_attempts: #{effective_max_attempts}, delay_seconds: #{effective_delay_seconds}"
    status_result = current_converter.check_status(
      status_endpoint,
      max_attempts: effective_max_attempts,
      delay_seconds: effective_delay_seconds
    )

    # status_result from check_status is expected to be like:
    # { status: 'SUCCESS', data: { "message": "...", "data_key": "...", ... } }
    # OR { status: 'FAILURE'/'TIMEOUT'/'UNKNOWN_API_STATUS', error: "...", ... }

    unless status_result && status_result[:status] == 'SUCCESS'
      error_message = "Conversion failed, timed out, or encountered an API error during status check: #{status_result ? status_result[:status] : 'Unknown Status'}"
      details = if status_result
                  status_result[:error] || status_result[:data] || status_result # Provide best available details
                else
                  'No status result object returned from check_status.'
                end
      puts "[TOOL ERROR] #{error_message} Details: #{details.inspect}"
      return { status: 'FAILURE', error: error_message, details: details }
    end

    puts "[TOOL INFO] Conversion status SUCCESS. API Data: #{status_result[:data].inspect}"

    # 3. Retrieve and extract the results
    # CRITICAL FIX: Use task_id_from_submission, NOT something from status_result[:data]
    # The status_result[:data] contains the `data_key` which is "conversion_result:TASK_ID",
    # but `retrieve_and_extract_zip_result` expects the raw TASK_ID to build this key itself.

    puts "[TOOL INFO] Attempting to retrieve and extract result using Task ID: #{task_id_from_submission}"
    extraction_result = current_converter.retrieve_and_extract_zip_result(task_id_from_submission)

    unless extraction_result && extraction_result[:status] == 'SUCCESS'
      error_message = 'Error retrieving or extracting result after successful conversion.'
      details = extraction_result ? (extraction_result[:error] || extraction_result) : 'No extraction result object.'
      puts "[TOOL ERROR] #{error_message} Details: #{details.inspect}"
      return { status: 'FAILURE', error: error_message, details: details }
    end

    output_path = extraction_result[:output_path]
    puts "[TOOL INFO] Extraction successful. Output path: #{output_path}"

    # 4. Process the output path and list files
    files = []
    if output_path && Dir.exist?(output_path)
      # List files, excluding '.' and '..'
      files = Dir.children(output_path) # Dir.children is cleaner than Dir.entries.reject
      puts "[TOOL INFO] Found #{files.length} file(s)/director(ies) in output_path: #{files.join(', ')}"
    else
      error_message = 'Extraction reported success, but output path is invalid or does not exist.'
      details = { output_path: output_path, expected_task_id: task_id_from_submission }
      puts "[TOOL ERROR] #{error_message} Details: #{details.inspect}"
      return { status: 'FAILURE', error: error_message, details: details }
    end

    # Successfully completed the entire process
    success_payload = {
      status: 'SUCCESS',
      message: 'Document converted and results extracted successfully.',
      task_id: task_id_from_submission, # Include the task_id for reference
      output_path: output_path,
      files: files,
      file_count: files.length
      # You could also include api_success_data if needed:
      # api_conversion_details: status_result[:data]
    }
    puts "[TOOL INFO] Process complete: #{success_payload.inspect}"
    success_payload
  rescue StandardError => e
    # Catch any other unexpected errors during tool's execution flow
    error_message = "An unexpected error occurred within the DoclingConverter tool execution: #{e.message}"
    puts "[TOOL CRITICAL ERROR] #{error_message}\nBacktrace: #{e.backtrace.join("\n  ")}"
    { status: 'FAILURE', error: error_message, details: e.backtrace }
  end
end
