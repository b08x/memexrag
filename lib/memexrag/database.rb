# frozen_string_literal: true

# So when running a command or a console,
# the application will execute even if it's
# Postgres database.

require 'redis'

require 'ohm'
require 'ohm/contrib'

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
    @db.create_table?(:documents) do
      primary_key :id, type: :uuid, default: Sequel.function(:gen_random_uuid)
      column :path, String
      column :type, String
      column :embedding, "vector(1536)" # Added embedding column
      column :metadata, :jsonb # Added metadata column
      index %i[path type]
    end
  end

  # Function to drop the database/tables if a condition is true
  def drop_tables
    logger.debug('Dropping tables')
    begin
      @db.drop_table?(:documents)
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
# DB.create_table? (:documents) do
#   primary_key :id, type: :Bignum
#   column :pageContent, String
#   jsonb :metadata
#   column :embedding, "vector(1536)"

#   foreign_key :topic_id, :topics
#   full_text_index :pageContent
#   index :metadata
# end

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
