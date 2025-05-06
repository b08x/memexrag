# frozen_string_literal: true

require 'erb'
require 'pry'
require 'pry-stack_explorer'
require 'thor'
require 'json'
require 'yaml'
require 'ruby-spacy'
require 'jongleur'
require 'ruby_llm'

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
require_relative 'memexrag/database'
require_relative 'memexrag/command'

# Jongleur::WorkerTask is a class that defines a task to be executed by Jongleur.
# class Jongleur::WorkerTask
#   # Initialize a Redis connection.
#   begin
#     redis_connection = RedisConnection.new
#     @redis_tracker = redis_connection.redis
#   rescue Redis::CannotConnectError
#     puts "heeeey! Unable to connect to redis\n"
#     exit
#   end
# end

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


