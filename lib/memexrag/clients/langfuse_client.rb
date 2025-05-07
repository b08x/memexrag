# frozen_string_literal: true

require 'pycall'
require 'json' # For parsing potential error details or configs

# LangfuseClient: A Ruby interface to the Langfuse Python SDK for prompt management.
module LangfuseClient
  # Base error class for all LangfuseClient specific errors.
  class Error < StandardError; end

  # Raised when authentication with Langfuse fails.
  class AuthenticationError < Error; end

  # Raised for network or connection issues when communicating with the Langfuse API.
  class ApiConnectionError < Error; end

  # Raised when a requested resource (e.g., a prompt) is not found.
  class NotFoundError < Error; end

  # Raised for invalid requests to the Langfuse API (e.g., bad parameters).
  class InvalidRequestError < Error; end

  # Raised for other generic API errors from Langfuse.
  class LangfuseApiError < Error; end

  # Manages configuration for the Langfuse client.
  class Config
    attr_reader :public_key, :secret_key, :host

    def initialize(public_key: nil, secret_key: nil, host: nil)
      @public_key = public_key || ENV.fetch('LANGFUSE_PUBLIC_KEY', nil)
      @secret_key = secret_key || ENV.fetch('LANGFUSE_SECRET_KEY', nil)
      @host = host || ENV['LANGFUSE_HOST'] || 'https://cloud.langfuse.com' # Default host

      raise ArgumentError, 'Langfuse public key is missing.' unless @public_key && !@public_key.empty?
      raise ArgumentError, 'Langfuse secret key is missing.' unless @secret_key && !@secret_key.empty?
    end
  end

  # Represents a Langfuse Prompt.
  class Prompt
    attr_accessor :name, :version, :prompt_content, :config, :labels, :tags, :type, :commit_message
    attr_reader :raw_python_object # For debugging or advanced interop

    def initialize(name:, version:, prompt_content:, type:, config: {}, labels: [], tags: [], commit_message: nil, raw_python_object: nil)
      @name = name
      @version = version.to_i # Ensure Integer
      @prompt_content = prompt_content # String for text, Array of Hashes for chat
      @type = type.to_s # String: 'text' or 'chat'
      @config = config # Hash
      @labels = labels # Array of Strings
      @tags = tags # Array of Strings
      @commit_message = commit_message # String or nil
      @raw_python_object = raw_python_object
    end

    def compile(variables = {})
      case @type
      when 'text'
        temp_content = @prompt_content.is_a?(String) ? @prompt_content.dup : @prompt_content.to_s
        variables.each do |key, value|
          temp_content.gsub!("{{#{key}}}", value.to_s)
        end
        temp_content
      when 'chat'
        if @prompt_content.is_a?(Array)
          @prompt_content.map do |message|
            current_message = message.is_a?(Hash) ? message.transform_keys(&:to_sym) : {}
            if current_message[:content].is_a?(String)
              compiled_msg_content = current_message[:content].dup
              variables.each do |key, value|
                compiled_msg_content.gsub!("{{#{key}}}", value.to_s)
              end
              current_message.merge(content: compiled_msg_content)
            else
              current_message
            end
          end
        else
          @prompt_content
        end
      else
        @prompt_content
      end
    end

    def self.from_python(py_prompt_obj)
      to_ruby_array = ->(py_list) { py_list && py_list.respond_to?(:to_a) ? py_list.to_a.map(&:to_s) : [] }
      to_ruby_hash = lambda do |py_dict|
        return {} unless py_dict && py_dict.respond_to?(:to_h)

        begin
          py_dict.to_h.transform_keys(&:to_s)
        rescue PyCall::PyError
          ruby_hash = {}
          py_dict.items.to_a.each { |item_tuple| ruby_hash[item_tuple[0].to_s] = item_tuple[1] } if py_dict.respond_to?(:items)
          ruby_hash
        end
      end

      prompt_type_str = 'text'
      prompt_content_val = 'Content not directly available'
      config_val = {}

      # Get Python class name correctly
      py_class_name = py_prompt_obj.__class__.__name__.to_s

      prompt_type_str = py_prompt_obj.type.to_s if py_prompt_obj.respond_to?(:type) && py_prompt_obj.type

      if py_prompt_obj.respond_to?(:prompt) && py_prompt_obj.prompt
        raw_prompt_data = py_prompt_obj.prompt
        prompt_content_val = if prompt_type_str == 'chat' && raw_prompt_data.respond_to?(:to_a)
                               raw_prompt_data.to_a.map { |msg_obj| { role: msg_obj.role.to_s, content: msg_obj.content.to_s } }
                             else
                               raw_prompt_data.to_s
                             end
      end

      config_val = to_ruby_hash.call(py_prompt_obj.config) if py_prompt_obj.respond_to?(:config) && py_prompt_obj.config

      if py_class_name == 'PromptMeta' && py_prompt_obj.respond_to?(:last_config) && py_prompt_obj.last_config
        meta_config = to_ruby_hash.call(py_prompt_obj.last_config)
        config_val = meta_config
        inferred_type = meta_config['type']&.to_s
        inferred_content_raw = meta_config['prompt']

        prompt_type_str = inferred_type if inferred_type

        if inferred_content_raw
          prompt_content_val = if prompt_type_str == 'chat' && inferred_content_raw.is_a?(Array)
                                 inferred_content_raw.map { |m| { role: m['role'].to_s, content: m['content'].to_s } }
                               else
                                 inferred_content_raw.to_s
                               end
        elsif prompt_type_str == 'chat'
          prompt_content_val = []
        end
      end

      version_val = py_prompt_obj.respond_to?(:version) && !py_prompt_obj.version.nil? ? py_prompt_obj.version.to_i : 0
      if py_class_name == 'PromptMeta' && py_prompt_obj.respond_to?(:versions) && py_prompt_obj.versions.respond_to?(:to_a) && !py_prompt_obj.versions.to_a.empty?
        version_val = py_prompt_obj.versions.to_a.map(&:to_i).max || 0
      end

      commit_msg_val = py_prompt_obj.respond_to?(:commit_message) && py_prompt_obj.commit_message ? py_prompt_obj.commit_message.to_s : nil

      new(
        name: py_prompt_obj.name.to_s,
        version: version_val,
        prompt_content: prompt_content_val,
        type: prompt_type_str,
        config: config_val,
        labels: to_ruby_array.call(py_prompt_obj.labels),
        tags: to_ruby_array.call(py_prompt_obj.tags),
        commit_message: commit_msg_val,
        raw_python_object: py_prompt_obj
      )
    rescue PyCall::PyError => e
      py_obj_dir_str = begin
        py_prompt_obj.dir.to_a.join(', ')
      rescue StandardError
        'N/A'
      end
      raise LangfuseClient::Error, "Failed to convert Python prompt object due to PyCall error: #{e.message}. Attributes: #{py_obj_dir_str}"
    rescue NoMethodError => e
      py_obj_class_name_str = begin
        py_prompt_obj.__class__.__name__.to_s
      rescue StandardError
        'N/A'
      end
      py_obj_dir_str = begin
        py_prompt_obj.dir.to_a.join(', ')
      rescue StandardError
        'N/A'
      end
      raise LangfuseClient::Error,
            "Python prompt object missing expected attribute for conversion: #{e.message}. Object type: #{py_obj_class_name_str}. Attributes: #{py_obj_dir_str}"
    end
  end

  # Client for interacting with the Langfuse API via Python SDK.
  class Client
    attr_reader :config, :py_langfuse_client, :langfuse_python_module

    def initialize(config_options = {})
      @config = config_options.is_a?(Config) ? config_options : Config.new(**config_options.transform_keys(&:to_sym))

      setup_pycall
      @langfuse_python_module = PyCall.import_module('langfuse')
      @py_langfuse_client = @langfuse_python_module.Langfuse.call(
        public_key: @config.public_key,
        secret_key: @config.secret_key,
        host: @config.host
      )

      auth_check!
    rescue PyCall::PyError => e
      raise ApiConnectionError, "Failed to initialize Langfuse Python client: #{e.message} - Python traceback: #{fetch_python_traceback(e)}"
    rescue ArgumentError => e # Catches errors from Config.new
      raise LangfuseClient::Error, "Configuration error: #{e.message}"
    end

    def auth_check!
      is_authed = @py_langfuse_client.auth_check # Call Python method
      raise AuthenticationError, 'Langfuse authentication check failed. Verify API keys and host.' unless is_authed

      true
    rescue PyCall::PyError => e
      py_error_message = e.message.to_s.downcase
      if py_error_message.include?('unauthorized') || py_error_message.include?('forbidden')
        raise AuthenticationError, "Langfuse authentication failed: #{e.message} - Python traceback: #{fetch_python_traceback(e)}"
      end

      raise ApiConnectionError, "Langfuse auth_check call failed: #{e.message} - Python traceback: #{fetch_python_traceback(e)}"
    end

    def create_prompt(name:, prompt_content:, type: 'text', config: {}, labels: [], tags: [], commit_message: nil)
      raise ArgumentError, "Invalid prompt type: '#{type}'. Must be 'text' or 'chat'." unless %w[text chat].include?(type.to_s)

      sdk_prompt_params = {
        name: name,
        prompt: prompt_content,
        type: type.to_s,
        config: config,
        labels: labels,
        tags: tags
      }
      sdk_prompt_params[:commit_message] = commit_message if commit_message

      # The Langfuse Python SDK's Langfuse class has a create_prompt method directly.
      py_created_prompt = @py_langfuse_client.create_prompt(**sdk_prompt_params)
      Prompt.from_python(py_created_prompt)
    rescue PyCall::PyError => e
      handle_py_error(e, context_message: "Failed to create prompt '#{name}'")
    rescue LangfuseClient::Error
      raise
    rescue ArgumentError => e
      raise InvalidRequestError, e.message
    rescue StandardError => e
      raise LangfuseClient::Error, "An unexpected Ruby error occurred while creating prompt '#{name}': #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
    end

    def get_prompt(name:, version: nil, label: nil)
      # The Langfuse Python SDK's Langfuse class has a get_prompt method directly
      py_prompt_obj = @py_langfuse_client.get_prompt(name: name, version: version, label: label)
      Prompt.from_python(py_prompt_obj)
    rescue PyCall::PyError => e
      error_message_lower = e.message.to_s.downcase
      if error_message_lower.include?('prompt not found') ||
         (e.respond_to?(:type) && e.type.to_s.downcase.include?('notfounderror'))
        raise NotFoundError, "Prompt '#{name}' (version: #{version || 'any'}, label: #{label || 'any'}) not found. Original error: #{e.message}"
      else
        handle_py_error(e, context_message: "Failed to get prompt '#{name}'")
      end
    rescue LangfuseClient::Error
      raise
    rescue StandardError => e
      raise LangfuseClient::Error, "An unexpected Ruby error occurred while getting prompt '#{name}': #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
    end

    def list_prompts(name: nil, label: nil, tags: nil, limit: nil, page: nil)
      sdk_params = {}
      sdk_params[:name] = name if name
      sdk_params[:label] = label if label
      sdk_params[:tags] = tags if tags
      sdk_params[:limit] = limit.to_i if limit
      sdk_params[:page] = page.to_i if page

      # Corrected: Access list method via .api.prompts on the Langfuse client instance
      py_response = @py_langfuse_client.api.prompts.list(**sdk_params)

      raise LangfuseClient::Error, "Langfuse Python SDK's prompt list response is malformed: missing 'data' attribute." unless py_response.respond_to?(:data)

      py_prompt_meta_list = py_response.data
      py_prompt_meta_list.to_a.map do |py_prompt_meta|
        Prompt.from_python(py_prompt_meta)
      end
    rescue PyCall::PyError => e
      handle_py_error(e, context_message: 'Failed to list prompts')
    rescue LangfuseClient::Error
      raise
    rescue StandardError => e
      raise LangfuseClient::Error, "An unexpected Ruby error occurred while listing prompts: #{e.class} - #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}"
    end

    def prompt_exists?(name:)
      raise ArgumentError, 'Prompt name cannot be empty.' if name.nil? || name.strip.empty?

      begin
        get_prompt(name: name)
        true
      rescue NotFoundError
        false
      rescue LangfuseClient::Error => e
        raise LangfuseClient::Error, "Failed to check prompt existence for '#{name}' due to: #{e.message}"
      end
    end

    private

    def setup_pycall
      PyCall.init
    rescue PyCall::PyError => e
      raise LangfuseClient::Error, "Failed to initialize PyCall: #{e.message}. Ensure Python and PyCall are correctly set up."
    end

    def fetch_python_traceback(py_error)
      return 'No Python traceback available.' unless py_error.respond_to?(:traceback) && py_error.traceback

      tb_obj = py_error.traceback
      return 'Python traceback object is nil.' if tb_obj.nil?
      return tb_obj.to_s unless tb_obj.is_a?(PyCall::Object)

      begin
        py_traceback_mod = PyCall.import_module('traceback')
        py_exc_type = py_error.respond_to?(:type) ? py_error.type : py_error.class.to_s
        py_exc_value = py_error.respond_to?(:value) ? py_error.value : py_error
        formatted_list = py_traceback_mod.format_exception(py_exc_type, py_exc_value, tb_obj)
        return formatted_list.to_a.join('') if formatted_list.respond_to?(:to_a)
      rescue PyCall::PyError, StandardError
        # Fallback
      end
      tb_obj.to_s
    rescue StandardError
      'Could not retrieve Python traceback due to an unexpected Ruby error.'
    end

    def handle_py_error(py_error, context_message: '')
      py_error_body = py_error.respond_to?(:body) ? py_error.body : nil
      details = ''
      if py_error_body
        begin
          body_data = py_error_body.respond_to?(:to_h) ? py_error_body.to_h : JSON.parse(py_error_body.to_s)
          details = body_data['message'] || body_data['detail'] || body_data.to_s
        rescue JSON::ParserError, PyCall::PyError
          details = py_error_body.to_s
        end
      end

      full_message = "#{context_message}: #{py_error.message}."
      full_message += " Details: #{details}." if details && !details.empty?
      full_message += " Python traceback: #{fetch_python_traceback(py_error)}"

      error_str = py_error.message.to_s.downcase
      status_code = py_error.respond_to?(:status_code) && py_error.status_code ? py_error.status_code.to_i : 0

      if status_code == 404 || error_str.include?('not found')
        raise NotFoundError, full_message
      elsif [401, 403].include?(status_code) || error_str.include?('unauthorized') || error_str.include?('forbidden')
        raise AuthenticationError, full_message
      elsif [400, 422].include?(status_code) || error_str.include?('bad request') || error_str.include?('invalid')
        raise InvalidRequestError, full_message
      else
        raise LangfuseApiError, full_message
      end
    end
  end
end
