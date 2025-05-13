# frozen_string_literal: true

# app.rb
# Sinatra application with file upload and NLP workflow proxy.
lib_dir = File.expand_path(File.join(__dir__, 'lib'))
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include?(lib_dir)
p lib_dir
require 'sinatra'
require 'slim'
require 'fileutils'
require 'json'
require 'httparty'
require 'dotenv/load' # Loads variables from .env
require 'memexrag' # Load logging module

# --- Sinatra Configuration ---
set :views, File.join(File.dirname(__FILE__), 'views')
set :public_folder, File.join(File.dirname(__FILE__), 'public')
set :uploads_dir, File.join(settings.public_folder, 'uploads')

FileUtils.mkdir_p(settings.uploads_dir) unless Dir.exist?(settings.uploads_dir)

include Logging # Make logger available
logger.debug('hello')
# --- Constants ---
SUPPORTED_LANGUAGES = %w[en es ta fr de].freeze # Define supported languages

# --- Routes ---

get '/' do
  "<h1>Welcome!</h1><p>Go to <a href='/translate'>/translate</a> to see the translation page.</p>"
end

post '/upload' do
  content_type :json
  if params[:file] && params[:file][:tempfile]
    uploaded_file = params[:file]
    filename = uploaded_file[:filename]
    tempfile_path = uploaded_file[:tempfile].path
    safe_filename = filename.gsub(/[^0-9A-Za-z.\-_]/, '_') # Basic sanitization
    destination_path = File.join(settings.uploads_dir, safe_filename)
    begin
      FileUtils.mv(tempfile_path, destination_path)
      { status: 'success', message: 'File uploaded successfully.', id: safe_filename, path: "/uploads/#{safe_filename}" }.to_json
    rescue StandardError => e
      status 500
      { status: 'error', message: "Failed to save file: #{e.message}" }.to_json
    end
  else
    status 400
    { status: 'error', message: 'No file uploaded or file data is missing.' }.to_json
  end
end

# Configure temporary upload directory
UPLOAD_FOLDER = File.join(settings.public_folder, 'uploads', 'temp_docling')
FileUtils.mkdir_p(UPLOAD_FOLDER) unless Dir.exist?(UPLOAD_FOLDER)

# Helper to instantiate the converter
def docling_converter
  # Ensure environment variables for URLs are set or use defaults
  MemexRAG::Processors::DoclingConverter.new
end

# --- Route 1: Handle Initial File Upload ---
post '/upload_document' do
  content_type :json

  unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
    logger.warn 'Upload attempt failed: Missing file parameters.'
    status 400
    return { error: 'No file uploaded or invalid parameters.' }.to_json
  end

  # Securely save the uploaded file temporarily
  temp_path = nil # Define outside begin block for ensure clause
  submit_result = nil # Define outside begin block for ensure clause
  begin
    # Add a timestamp or unique ID to prevent overwrites if needed
    original_filename = name
    timestamp = Time.now.to_i
    sanitized_filename = original_filename.gsub(/[^0-9A-Za-z.\-_]/, '_')
    temp_path = File.join(settings.uploads_dir, "#{timestamp}-#{sanitized_filename}")

    FileUtils.copy(tmpfile.path, temp_path)
    logger.info "Uploaded file saved temporarily to: #{temp_path}"

    # Submit to DoclingConverter
    converter = docling_converter
    submit_result = converter.submit_file(temp_path)

    if submit_result && submit_result[:task_id]
      logger.info "File '#{sanitized_filename}' submitted for conversion, task_id: #{submit_result[:task_id]}"
      status 202 # Accepted
      # Return the task ID and status endpoint path to the client
      submit_result.to_json
    else
      logger.error "Failed to submit file '#{sanitized_filename}' for conversion via DoclingConverter."
      status 500
      { error: 'Failed to submit file for conversion.' }.to_json
    end
  rescue StandardError => e
    logger.error "Error during file upload/submission for '#{name}': #{e.message}\n#{e.backtrace.join("\n")}"
    status 500
    { error: "Server error during upload: #{e.message}" }.to_json
  ensure
    # Clean up the initially uploaded temp file from Sinatra/Rack if it exists
    # tmpfile.close! if tmpfile # Sinatra might handle this

    # Clean up the file we copied to settings.uploads_dir ONLY IF submission failed immediately
    if temp_path && File.exist?(temp_path) && (!submit_result || !submit_result[:task_id])
      FileUtils.rm_f(temp_path)
      logger.info "Cleaned up failed upload temp file: #{temp_path}"
    end
    # NOTE: If submission *succeeded*, the file at temp_path is potentially needed by the async process.
    # A robust cleanup strategy for these files (if conversion succeeds/fails later) is recommended.
  end
end

# --- Route 2: Check Task Status ---
get '/check_task_status' do
  content_type :json
  status_endpoint = params[:endpoint]

  unless status_endpoint && !status_endpoint.empty?
    logger.warn 'Status check failed: Missing endpoint parameter.'
    status 400
    return { error: 'Missing status endpoint parameter.' }.to_json
  end

  begin
    converter = docling_converter
    # Using default polling settings defined within the check_status method
    status_result = converter.check_status(status_endpoint)
    logger.debug "Status check result for #{status_endpoint}: #{status_result[:status]}"
    status_result.to_json
  rescue StandardError => e
    logger.error "Error checking task status for endpoint #{status_endpoint}: #{e.message}\n#{e.backtrace.join("\n")}"
    status 500
    { error: "Server error checking status: #{e.message}" }.to_json
  end
end

# --- Route 3: Retrieve and Extract Result Text ---
get '/retrieve_result' do
  content_type :json
  sidekiq_jid = params[:jid]

  unless sidekiq_jid && !sidekiq_jid.empty?
    logger.warn 'Result retrieval failed: Missing JID parameter.'
    status 400
    return { error: 'Missing sidekiq job ID parameter.' }.to_json
  end

  output_path = nil # To ensure cleanup happens correctly in ensure block
  begin
    converter = docling_converter
    extraction_result = converter.retrieve_and_extract_zip_result(sidekiq_jid)

    if extraction_result[:status] == 'SUCCESS'
      output_path = extraction_result[:output_path] # Assign here for cleanup
      extracted_text = nil
      logger.info "Extraction successful for JID #{sidekiq_jid}. Output path: #{output_path}"

      # Find the primary text file (adjust logic as needed)
      # Prioritize .txt, then look for other common text formats
      # Consider character encoding issues here
      text_file_paths = Dir.glob("#{output_path}/**/*.txt") +
                        Dir.glob("#{output_path}/**/*.{md,html,xml,json}") # Add other types if necessary

      text_file_path = text_file_paths.first # Take the first match

      if text_file_path && File.exist?(text_file_path)
        logger.info "Found extracted text file: #{text_file_path}"
        begin
          # Attempt to read as UTF-8, handle potential encoding errors
          extracted_text = File.read(text_file_path, encoding: 'UTF-8')
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
          logger.warn "Encoding error reading #{text_file_path} as UTF-8: #{e.message}. Trying ISO-8859-1."
          begin
            extracted_text = File.read(text_file_path, encoding: 'ISO-8859-1').encode('UTF-8')
          rescue StandardError => fallback_error
            logger.error "Failed to read #{text_file_path} even with fallback encoding: #{fallback_error.message}"
            # Decide: return error or empty string? Returning error for now.
            status 500
            return { success: false, error: "Failed to read extracted file due to encoding issues: #{text_file_path}" }.to_json
          end
        end
        { success: true, text_content: extracted_text }.to_json
      else
        logger.warn "No primary text file (.txt, .md, .html, etc.) found in extraction directory: #{output_path} for JID #{sidekiq_jid}"
        status 404
        { success: false, error: 'Extracted text content file not found in the result.' }.to_json
      end
    else
      # Log the specific error from the converter
      error_message = extraction_result[:error] || 'Failed to retrieve or extract result.'
      logger.error "Result retrieval/extraction failed for JID #{sidekiq_jid}: #{error_message}"
      status 500 # Or map Docling errors to appropriate HTTP statuses if possible
      { success: false, error: error_message }.to_json
    end
  rescue StandardError => e
    logger.error "Unexpected error retrieving result for JID #{sidekiq_jid}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
    status 500
    { success: false, error: "Server error retrieving result: #{e.message}" }.to_json
  ensure
    # !!! CRITICAL: Clean up the temporary extraction directory !!!
    if output_path && Dir.exist?(output_path)
      begin
        FileUtils.remove_entry_secure(output_path)
        logger.info "Successfully cleaned up extraction directory: #{output_path}"
      rescue StandardError => e
        # Log this error, but don't let it fail the request if text was already potentially sent
        logger.error "!!! Failed to clean up extraction directory #{output_path}: #{e.message}"
      end
    end
  end
end

get '/radiology/translate' do
  # --- Fetch dynamic data here ---
  # Example: Replace with actual data fetching logic
  @source_languages = [%w[en English], %w[ta Tamil], %w[es Spanish]] # Fetch from config or service
  @target_languages = [%w[ta Tamil], %w[en English], %w[hi Hindi]] # Fetch from config or service
  @glossary_items = [
    { term: 'RIS', definition: 'Radiology Information System' },
    { term: 'PACS', definition: 'Picture Archiving and Communication System' }
    # Fetch from database or service
  ]
  @recent_translations = [
    { title: 'RIS-PACS integration guide', langs: 'English → Tamil', time: '2 hours ago' }
    # Fetch from database or service
  ]

  # Render the Slim template
  slim :radiology_translate # Assumes views/radiology_translate.slim exists
end

# --- You will also need backend routes (proxies) ---

# Proxy for Text Translation using the new TranslationService
post '/memexrag/proxy/translate' do
  content_type :json
  begin
    request_payload = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Received translation request: #{request_payload.slice(:source_language, :target_language)}" # Log basic info

    # --- 1. Validation ---
    text = request_payload[:text]
    source_lang = request_payload[:source_language]&.downcase
    target_lang = request_payload[:target_language]&.downcase

    unless text && !text.strip.empty?
      logger.error 'Validation failed: Missing or empty text parameter.'
      halt 400, { error: 'Missing required parameter: text' }.to_json
    end
    unless source_lang && SUPPORTED_LANGUAGES.include?(source_lang)
      logger.error "Validation failed: Invalid or unsupported source language: #{source_lang}"
      halt 400, { error: "Invalid or unsupported source_language: #{request_payload[:source_language]}" }.to_json
    end
    unless target_lang && SUPPORTED_LANGUAGES.include?(target_lang)
      logger.error "Validation failed: Invalid or unsupported target language: #{target_lang}"
      halt 400, { error: "Invalid or unsupported target_language: #{request_payload[:target_language]}" }.to_json
    end
    if source_lang == target_lang
      logger.error 'Validation failed: Source and target languages cannot be the same.'
      halt 400, { error: 'Source and target languages cannot be the same' }.to_json
    end

    # --- 2. Instantiate Service ---
    # Consider making this a singleton or request-scoped instance for efficiency later
    begin
      translator = MemexRAG::Services::Translator.new
      logger.info 'Translator service instantiated successfully.'
    rescue MemexRAG::Services::Translator::ConfigurationError => e
      logger.fatal "Failed to initialize Translator service due to configuration error: #{e.message}"
      halt 503, { error: 'Translation service is unavailable due to configuration issues.' }.to_json
    end

    logger.info "Validation successful for #{source_lang} -> #{target_lang} request."

    # --- 3. Call Service Method ---
    translated_text = translator.translate(
      text: text,
      source_lang: source_lang,
      target_lang: target_lang
    )

    # --- 4. Format and Return Response ---
    response_body = {
      translated_text: translated_text,
      source_language: source_lang,
      target_language: target_lang
    }
    logger.info "Translation successful for #{source_lang} -> #{target_lang}."
    response_body.to_json
  rescue JSON::ParserError => e
    logger.error "Failed to parse JSON payload: #{e.message}"
    status 400
    { error: "Invalid JSON payload: #{e.message}" }.to_json
  rescue MemexRAG::Services::Translator::ProviderError => e
    logger.error "Translation provider error (#{e.provider}): #{e.message}"
    # Log original error details if present and helpful
    logger.error "Original error: #{e.original_error.inspect}" if e.original_error
    status 503 # Service Unavailable from the provider's perspective
    { error: "Translation service provider failed: #{e.message}" }.to_json
  rescue MemexRAG::Services::Translator::TranslationError => e # Catch other specific translation errors
    logger.error "Translation service error: #{e.message}"
    status 500
    { error: "Translation failed: #{e.message}" }.to_json
  rescue StandardError => e # Catch unexpected errors
    logger.error "Unexpected error during translation request: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    status 500
    { error: 'An unexpected error occurred during translation.' }.to_json # More generic message
  end
end

# --- TODO: Add backend routes for ---
# - Media Upload (/memexrag/upload/media) -> Store media
# - Media Analysis (/memexrag/proxy/media_analysis) -> Call OCR/UI/Translation services
# - Translation Memory Lookup (/memexrag/api/tm_lookup)
# - Glossary Fetching (/memexrag/api/glossary)
# - Recent Translations Fetching (/memexrag/api/recent_translations)
