# frozen_string_literal: true

# app.rb
# Sinatra application with file upload and NLP workflow proxy.
lib_dir = File.expand_path(File.join(__dir__, 'lib'))
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include?(lib_dir)

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
  "<h1>Welcome!</h1><p>Go to <a href='/radiology/translate'>/translate</a> to see the translation page.</p>"
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

# Helper to instantiate the tool (could be done per request or cached if stateless)
def docling_tool
  @docling_tool ||= MemexRAG::Tools::DoclingConverter.new
  # Ensure any initialization errors in the tool are handled or logged.
  # The tool's constructor in lib/memexrag/tools/docling_converter.rb
  # already has a begin/rescue for its internal processor.
end

# --- New Synchronous Conversion Route ---
post '/convert_document' do
  content_type :json
  logger.info "Received request for synchronous document conversion."

  unless params[:file] && (tmpfile = params[:file][:tempfile]) && (original_filename = params[:file][:filename])
    logger.warn "Upload attempt failed: Missing file parameters."
    status 400
    return { status: 'FAILURE', error: 'No file uploaded or invalid parameters.' }.to_json
  end

  temp_saved_path = nil
  begin
    # Securely save the uploaded file temporarily
    # This path is where the tool will read the file from
    timestamp = Time.now.to_i
    sanitized_filename = original_filename.gsub(/[^0-9A-Za-z.\-_]/, '_')
    temp_dir = File.join(settings.uploads_dir, 'tool_processing') # Specific subdir for these temp files
    FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
    temp_saved_path = File.join(temp_dir, "#{timestamp}-#{sanitized_filename}")

    FileUtils.copy(tmpfile.path, temp_saved_path)
    logger.info "File '#{original_filename}' saved temporarily to: #{temp_saved_path} for synchronous tool processing."

    # Instantiate and execute the DoclingConverterTool
    # The tool's execute method is blocking and will handle submission, polling, and result structuring.
    tool_execution_result = docling_tool.execute(file_path: temp_saved_path)

    # The tool_execution_result is expected to be a hash like:
    # {
    #   status: 'SUCCESS' | 'FAILURE',
    #   message: '...', (on success)
    #   error: '...', (on failure)
    #   details: '...', (on failure)
    #   task_id: '...', (Docling service task_id)
    #   output_path: '...', (path to the extracted files from the tool's perspective)
    #   files: [...], (top-level files, for backward compat)
    #   file_count: ..., (top-level count, for backward compat)
    #   directory_structure: {...}, (the new rich structure)
    #   structure_metadata: {...} (metadata about the structure)
    # }

    if tool_execution_result[:status] == 'SUCCESS'
      logger.info "DoclingConverterTool executed successfully for file: #{original_filename}. Task ID: #{tool_execution_result[:task_id]}"
      # The output_path from the tool is likely within a Dir.mktmpdir created by the *tool itself*.
      # We might want to clean that up if the tool doesn't do it, but the tool should manage its own temp dirs.
      # The key is that the response already contains the structured data.
      status 200
      tool_execution_result.to_json
    else
      logger.error "DoclingConverterTool reported failure for file: #{original_filename}. Error: #{tool_execution_result[:error]}"
      status 500 # Or a more appropriate error code based on tool_execution_result
      tool_execution_result.to_json
    end

  rescue StandardError => e
    logger.error "Unexpected error during synchronous conversion for '#{original_filename}': #{e.class} - #{e.message}"
    e.backtrace.first(10).each { |line| logger.error line }
    status 500
    { status: 'FAILURE', error: "Server error during conversion: #{e.message}" }.to_json
  ensure
    # Clean up the temporarily saved uploaded file
    if temp_saved_path && File.exist?(temp_saved_path)
      FileUtils.rm_f(temp_saved_path)
      logger.info "Cleaned up temporary input file: #{temp_saved_path}"
    end
    # Note: The output_path from the tool (where the ZIP was extracted)
    # should ideally be cleaned up by the tool or have a defined lifecycle.
    # If `DoclingConverterTool#execute` uses `Dir.mktmpdir` without a block,
    # that temp dir might be left behind. It's better if `retrieve_and_extract_zip_result`
    # within the processor, or the tool itself, handles cleanup of its own extraction directory
    # *after* data (like `directory_structure`) has been gathered.
    # The `DoclingConverter` processor in `ruby-docling.rb` *does* cleanup its extraction dir if it created it.
    # The `DoclingConverterTool` uses the processor, so that cleanup should happen.
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
      translator = MemexRAG::Tools::Translator.new
      logger.info 'Translator service instantiated successfully.'
    rescue MemexRAG::Tools::Translator::ConfigurationError => e
      logger.fatal "Failed to initialize Translator service due to configuration error: #{e.message}"
      halt 503, { error: 'Translation service is unavailable due to configuration issues.' }.to_json
    end

    logger.info "Validation successful for #{source_lang} -> #{target_lang} request."

    # --- 3. Call Service Method ---
    translated_text = translator.execute(
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
  rescue MemexRAG::Tools::Translator::ProviderError => e
    logger.error "Translation provider error (#{e.provider}): #{e.message}"
    # Log original error details if present and helpful
    logger.error "Original error: #{e.original_error.inspect}" if e.original_error
    status 503 # Service Unavailable from the provider's perspective
    { error: "Translation service provider failed: #{e.message}" }.to_json
  rescue MemexRAG::Tool::Translator::TranslationError => e # Catch other specific translation errors
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
