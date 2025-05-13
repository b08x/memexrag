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
# - Document Upload (/memexrag/upload/document) -> Process file, extract text
# - Media Upload (/memexrag/upload/media) -> Store media
# - Media Analysis (/memexrag/proxy/media_analysis) -> Call OCR/UI/Translation services
# - Translation Memory Lookup (/memexrag/api/tm_lookup)
# - Glossary Fetching (/memexrag/api/glossary)
# - Recent Translations Fetching (/memexrag/api/recent_translations)
