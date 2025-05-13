#!/usr/bin/env ruby
# frozen_string_literal: true

# The Logging module provides a centralized way to handle logging
# across the application. It allows for configuring loggers with
# specific settings like log directory, level, max size, and max files.
#
# It can be included in any class to provide a `logger` instance method
# that is automatically configured with the class and method name.
module Logging
  module_function

  require 'logger'
  require 'fileutils' # Added for mkdir_p

  # @!visibility private
  # The directory where log files will be stored.
  # Defaults to `log` in the current working directory.
  LOG_DIR = File.expand_path(File.join(Dir.pwd, 'log'))

  # @!visibility private
  # The default logging level.
  # Set to `Logger::DEBUG`.
  LOG_LEVEL = Logger::DEBUG

  # @!visibility private
  # The maximum size of a single log file in bytes.
  # Defaults to 6MB (6 * 1024 * 1024).
  LOG_MAX_SIZE = 6_145_728 # 6MB

  # @!visibility private
  # The maximum number of log files to keep (for rotation).
  # Defaults to 10.
  LOG_MAX_FILES = 10

  # @!visibility private
  # A cache for logger instances, keyed by classname.
  # This prevents reconfiguring loggers unnecessarily.
  @loggers = {}

  # Provides a logger instance for the current class and method.
  #
  # The logger's `progname` will be set to "ClassName#methodName"
  # from where this method is called.
  #
  # @example
  #   class MyClass
  #     include Logging
  #
  #     def do_something
  #       logger.info "Doing something"
  #     end
  #   end
  #
  # @return [Logger] The logger instance for the calling context.
  def logger
    # Determines the class name of the object calling this method.
    # If called from a class method, `self` is the class itself.
    # If called from an instance method, `self.class` is the class.
    classname = is_a?(Module) ? name : self.class.name
    # Extracts the method name from the call stack.
    methodname = caller[0][/`([^']*)'/, 1]
    @logger ||= Logging.logger_for(classname, methodname)
    @logger.progname = "#{classname}##{methodname}"
    @logger
  end

  class << self
    # Returns the configured log level for new loggers.
    #
    # @return [Integer] The log level (e.g., `Logger::DEBUG`, `Logger::INFO`).
    def log_level
      LOG_LEVEL
    end

    # Retrieves or creates a logger for a given classname.
    #
    # Loggers are cached by classname to avoid redundant configuration.
    # The `methodname` parameter is currently passed to `configure_logger_for`
    # but not directly used in the default configuration of the log file name.
    #
    # @param classname [String] The name of the class for which to get the logger.
    # @param methodname [String] The name of the method (currently used to pass to `configure_logger_for`).
    # @return [Logger] The configured logger instance.
    def logger_for(classname, methodname)
      @loggers[classname] ||= configure_logger_for(classname, methodname)
    end

    def configure_logger_for(_classname, _methodname)
      current_date = Time.now.strftime('%Y-%m-%d')
      log_file = File.join(LOG_DIR, "memexrag-#{current_date}.log")
      # Ensure the log directory exists
      FileUtils.mkdir_p(LOG_DIR) unless Dir.exist?(LOG_DIR)
      logger = Logger.new(log_file, LOG_MAX_FILES, LOG_MAX_SIZE)
      logger.level = log_level
      logger
    end
  end
end
