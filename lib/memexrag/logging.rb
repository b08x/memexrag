#!/usr/bin/env ruby
# frozen_string_literal: true

module Logging
  module_function

  require 'logger'

  LOG_DIR = File.expand_path(File.join(Dir.pwd, 'log'))
  LOG_LEVEL = Logger::DEBUG
  LOG_MAX_SIZE = 6_145_728
  LOG_MAX_FILES = 10

  @loggers = {}

  def logger
    classname = self.class.name
    methodname = caller[0][/`([^']*)'/, 1]
    @logger ||= Logging.logger_for(classname, methodname)
    @logger.progname = "#{classname}##{methodname}"
    @logger
  end

  class << self
    def log_level
      Logger::DEBUG
    end

    def logger_for(classname, methodname)
      @loggers[classname] ||= configure_logger_for(classname, methodname)
    end

    def configure_logger_for(_classname, _methodname)
      current_date = Time.now.strftime('%Y-%m-%d')
      log_file = File.join(LOG_DIR, "memexrag-#{current_date}.log")
      logger = Logger.new(log_file, LOG_MAX_FILES, LOG_MAX_SIZE)
      logger.level = log_level
      logger
    end
  end
end

include Logging
