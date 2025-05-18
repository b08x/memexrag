# frozen_string_literal: true

# So when running a command or a console,
# the application will execute even if it's
# Postgres database.

require 'ohm'
require 'ohm/contrib'
require 'ohm/timestamps'
require 'ohm/json'

redis_ohm_uri ||= ENV.fetch('REDIS_OHM_URI', nil)
raise 'Env: REDIS_OHM_URI is not set' unless redis_ohm_uri

begin
  Ohm.redis = Redic.new(redis_ohm_uri)
  Ohm.redis.call('PING')
rescue Errno::ECONNREFUSED => e
  logger.warn "unable to connect to #{redis_ohm_uri}"
  puts "------\n"
  puts "warn: #{e}\n"
  puts "either the service isn't running or port isn't accessible...\n"
  puts "\nthat likely means the posgresql service isn't up either\n"
  puts "which won't be known until it's determined when and where to use the db"
  puts "------\n"
  sleep 0.5
end

require 'pg'
require 'pgvector'
require 'sequel'
require 'singleton'

class PGConnect
  include Singleton

  attr_reader :db

  def initialize
    postgres_uri ||= ENV.fetch('POSTGRES_URI', nil)
    raise 'Env: POSTGRES_URI is not set' unless postgres_uri

    begin
      @db = Sequel.connect(postgres_uri)
    rescue Sequel::DatabaseConnectionError => e
      logger.debug "#{e}"
      puts "info: #{e.cause}" if e.cause
      sleep 0.5
      return
    end

    @db.run('CREATE EXTENSION IF NOT EXISTS vector')
    @db.run('CREATE EXTENSION IF NOT EXISTS hstore')
    @db.run('CREATE EXTENSION IF NOT EXISTS pgcrypto') # Added for UUID support

    @db.extension :pg_array, :pg_hstore
    @db.extension :pg_json
    @db.wrap_json_primitives = true

    logger.debug('Connected to pg')
    create_tables
  rescue StandardError => e
    logger.fatal e.to_s
    puts "#{e}\nexiting\n"
    exit
  end

  def create_tables
    logger.info "Creating tables if they don't aleady exist"

    @db.create_table?(:chunks) do
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)
      text :pageContent, null: false
      jsonb :metadata
      column :embedding, 'vector(1024)' # BAAI/bge-large-en-v1.5 has 1024 dimensions

      index :embedding, type: :hnsw, opclass: :vector_cosine_ops # HNSW index for cosine similarity
    end

    @db.create_table?(:collections) do
      primary_key :id, type: :Bignum
      column :name, String, unique: true

      index %i[name]
    end

    @db.create_table?(:items) do
      primary_key :id, type: :uuid, default: Sequel.function(:gen_random_uuid)
      column :path, String, unique: true
      column :name, String
      column :extension, String
      column :type, String
      column :mime, String
      column :size, Integer

      foreign_key :collection_id, :collections

      index %i[path name extension type] # %i creates an array of symbols
    end
  end

  # Function to drop the database/tables if a condition is true
  def drop_tables
    logger.debug('Dropping tables')
    begin
      @db.drop_table?(:items)
      @db.drop_table?(:collections)
      @db.drop_table?(:files)
      @db.drop_table?(:documents)
      @db.drop_table?(:chunks)
      @db.disconnect
      logger.debug('Database and tables dropped successfully')
    rescue StandardError => e
      logger.fatal e.to_s
    end
  end
end

# V = PGConnect.instance

# Example of how to use the database connection now:
# DB = V.db
#

# DB.create_table? (:chunks) do
#   primary_key :id, type: :Bignum
#   column :text, String
#   jsonb :tokenized_text
#   jsonb :sanitized_text
#   foreign_key :document_id, :documents
#   index [:text, :document_id]
# end

# DB.create_table? (:words) do
#   primary_key :id, type: :Bignum
#   column :word, String
#   column :synsets, 'json'
#   column :part_of_speech, String
#   column :named_entity, String
#   foreign_key :chunk_id, :chunks
#   index [:word, :chunk_id]
# end

# DB.create_table? (:embeddings) do
#   primary_key :id, type: :Bignum
#   column :vector, "vector(1536)"
#   foreign_key :chunk_id, :chunks
#   foreign_key :topic_id, :topics
#   index [:vector, :chunk_id, :topic_id]
# end

# Initialize the database connection from PGConnect singleton
pg_connection_instance = PGConnect.instance

# Assign the database connection to Sequel::Model
# This ensures all Sequel models will use this connection.
raise 'Critical: Database connection not available from PGConnect for Sequel models.' unless pg_connection_instance&.db

Sequel::Model.db = pg_connection_instance.db

# If the DB connection isn't available, it's a critical issue for Sequel models.

# require_relative 'models/sequel/document'

require_relative 'models/sequel/chunk'
require_relative 'models/sequel/document_record'
require_relative 'models/sequel/collection'
require_relative 'models/sequel/item'

require_relative 'models/ohm/document'
require_relative 'models/ohm/topic'
require_relative 'models/ohm/page'
require_relative 'models/ohm/paragraph'
require_relative 'models/ohm/sentence'
require_relative 'models/ohm/phrase'
require_relative 'models/ohm/word'
