# frozen_string_literal: true

module MemexRAG
  module Config
    def self.load
      config_path = File.join(File.dirname(__FILE__), 'config', 'ruby_llm.yml')

      if File.exist?(config_path)
        raw = ERB.new(File.read(config_path)).result
        file_config = YAML.safe_load(raw, aliases: true, symbolize_names: true)

        RubyLLM.configure do |config|
          config.openai_api_key = file_config[:openai_api_key]
          config.gemini_api_key = file_config[:gemini_api_key]
          config.openai_api_base = file_config[:openai_api_base]
          config.default_model = file_config[:default_model] || 'gemini-2.0-flash'
          config.default_embedding_model = file_config[:default_embedding_model] || 'text-embedding-004'
          config.default_image_model = file_config[:default_image_model] || 'imagen-3.0-generate-002'
          config.request_timeout = file_config[:request_timeout] || 120
          config.max_retries = file_config[:max_retries] || 3
          config.retry_interval = file_config[:retry_interval] || 0.5
          config.retry_backoff_factor = file_config[:retry_backoff_factor] || 2
          config.retry_interval_randomness = file_config[:retry_interval_randomness] || 0.5
        end
      else
        puts 'Warning: config/ruby_llm.yml not found. Using default configuration.'

        RubyLLM.configure do |config|
          config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
          config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
          config.openai_api_base = ENV.fetch('OPENAI_API_BASE', nil)
          config.default_model = 'gemini-2.0-flash'
          config.default_embedding_model = 'text-embedding-004'
          config.default_image_model = 'imagen-3.0-generate-002'
          config.request_timeout = 120
          config.max_retries = 3
          config.retry_interval = 0.5
          config.retry_backoff_factor = 2
          config.retry_interval_randomness = 0.5
        end
      end
    end
  end
end
