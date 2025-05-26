# frozen_string_literal: true

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

require_relative 'ohm/topic'
require_relative 'ohm/paragraph'
require_relative 'ohm/sentence'
require_relative 'ohm/phrase'
require_relative 'ohm/word'
