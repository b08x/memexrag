# frozen_string_literal: true

# app.rb
# Sinatra application with file upload and NLP workflow proxy.

require 'sinatra'
require 'slim'
require 'fileutils'
require 'json'
require 'httparty'
require 'dotenv/load' # Loads variables from .env

# --- Sinatra Configuration ---
set :views, File.join(File.dirname(__FILE__), 'views')
set :public_folder, File.join(File.dirname(__FILE__), 'public')
set :uploads_dir, File.join(settings.public_folder, 'uploads')

FileUtils.mkdir_p(settings.uploads_dir) unless Dir.exist?(settings.uploads_dir)

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

# Example Proxy for Text Translation (using NLP processor or similar)
post '/memexrag/proxy/translate' do
  content_type :json
  request_payload = JSON.parse(request.body.read, symbolize_names: true)

  text_to_translate = request_payload[:text]
  source_lang = request_payload[:source]
  target_lang = request_payload[:target] # Replace with actual user tracking

  # --- TODO: Implement actual translation logic ---
  # This might involve:
  # 1. Instantiating your NLP processor (or other translation service client)
  # 2. Preparing the 'inputs' hash for the specific Dify workflow
  # 3. Calling the client (e.g., dify_client.execute_workflow_streaming or a non-streaming version)
  # 4. Handling errors and formatting the response

  # --- Mock Response ---
  sleep 1.5 # Simulate delay
  mock_translation = "(Backend Mock) Translated '#{text_to_translate[0..20]}...' from #{source_lang} to #{target_lang}"
  { translated_text: mock_translation }.to_json
  # --- End Mock Response ---
rescue JSON::ParserError => e
  status 400
  { error: "Invalid JSON payload: #{e.message}" }.to_json
rescue StandardError => e
  # logger.error "Translation proxy error: #{e.message}" # Use your logger
  status 500
  { error: "Translation failed: #{e.message}" }.to_json
end

# --- TODO: Add backend routes for ---
# - Document Upload (/memexrag/upload/document) -> Process file, extract text
# - Media Upload (/memexrag/upload/media) -> Store media
# - Media Analysis (/memexrag/proxy/media_analysis) -> Call OCR/UI/Translation services
# - Translation Memory Lookup (/memexrag/api/tm_lookup)
# - Glossary Fetching (/memexrag/api/glossary)
# - Recent Translations Fetching (/memexrag/api/recent_translations)
