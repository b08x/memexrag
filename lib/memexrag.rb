# frozen_string_literal: true

require 'erb'
require 'pry'
require 'pry-stack_explorer'
require 'thor'
require 'json'
require 'yaml'
require 'jongleur'
require 'ruby_llm'
require 'time'
require 'redis'
require 'mimemagic'

require 'dotenv/load'

# Check if .env file exists before attempting to load
if File.exist?('.env')
  Dotenv.load('.env', overwrite: true)
else
  puts "\nWARN: .env file not found. Proceeding without environment variables from .env.\n\n"
end

require_relative 'memexrag/version'
require_relative 'memexrag/config'
require_relative 'memexrag/logging'

include Logging

require_relative 'memexrag/ui'

require_relative 'memexrag/nlp/spacy_model_registry'
require_relative 'memexrag/processors/ruby-docling'
require_relative 'memexrag/processors/multilingual'
require_relative 'memexrag/processors/loader'
require_relative 'memexrag/processors/gtranslate'
require_relative 'memexrag/clients/dify_client'
require_relative 'memexrag/clients/flowise_client'
require_relative 'memexrag/clients/langfuse_client'
require_relative 'memexrag/tools/semantic_search'
require_relative 'memexrag/tools/spacy_nlp'
require_relative 'memexrag/tools/docling_converter'
require_relative 'memexrag/tools/image_converter'
require_relative 'memexrag/database'
require_relative 'memexrag/command'

require_relative 'memexrag/filediscovery'
require_relative 'memexrag/fileobject'
require_relative 'memexrag/parser'

require_relative 'memexrag/import'

require_relative 'memexrag/workflow_orchestrator'

# Jongleur::WorkerTask is a class that defines a task to be executed by Jongleur.
class Jongleur::WorkerTask
  # Initialize a Redis connection.
  begin
    redis_connection = Redis.new(host: 'localhost', port: 6379, db: 15)
    @redis = redis_connection
  rescue Redis::CannotConnectError
    puts "heeeey! Unable to connect to redis\n"
    exit
  end
end

require_relative 'memexrag/cli'

module MemexRAG
  class Error < StandardError; end
  Config.load
  puts '...configuration loaded'
  sleep 1
  def self.root
    File.dirname __dir__
  end
end

puts "\nstuff declared here happens before a command is run\n"
sleep 0.5

puts "but this doesn't run?"
`clear`


