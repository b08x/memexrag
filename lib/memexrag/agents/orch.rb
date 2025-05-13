#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tty-prompt'
require 'ruby-llm'
require 'langfuse-rb'

# Orchestrates the execution of Chatbot workflows.
# Integrates TTY-Prompt for interactive UI, RubyLLM for LLM interactions, and Langfuse for tracing.
class ChatbotOrchestrator
  # Initializes a new ChatbotOrchestrator instance.
  #
  # @param langfuse_config [Hash, nil] Configuration for LangfuseClient.
  #   Example: { public_key: '...', secret_key: '...', host: '...' }
  #   If nil, LangfuseClient will not be initialized.
  # @return [void]
  def initialize(langfuse_config: nil)
    @prompt = TTY::Prompt.new
    @llm = LLM.new(model: 'gpt-3.5-turbo') # Default model, can be configured
    @langfuse = initialize_langfuse(langfuse_config)
    @trace = nil # Langfuse trace object
  end

  # Initializes Langfuse client if configuration is provided.
  #
  # @param langfuse_config [Hash, nil] Langfuse configuration.
  # @return [Langfuse::Client, nil] Langfuse client instance or nil if config is missing.
  def initialize_langfuse(langfuse_config)
    if langfuse_config
      Langfuse::Client.new(langfuse_config)
    else
      puts 'Langfuse not configured.'
      nil
    end
  end

  # Starts a new Langfuse trace.
  #
  # @param trace_id [String] Unique identifier for the trace.
  # @param name [String] Name of the trace.
  # @return [void]
  def start_trace(trace_id, name: 'Chatbot Session')
    return unless @langfuse # Skip if Langfuse is not configured

    @trace = @langfuse.trace(id: trace_id, name: name)
    puts "Starting Langfuse trace with ID: #{trace_id}"
  end

  # Runs the chatbot workflow.
  #
  # This method presents the user with prompts, interacts with the LLM, and
  # logs the interactions using Langfuse.
  #
  # @return [void]
  def run_chatbot
    puts 'Starting chatbot...'
    start_trace("chatbot-session-#{Time.now.to_i}") if @langfuse

    loop do
      user_input = @prompt.ask('You:')
      break if user_input.downcase == 'exit'

      llm_response = generate_llm_response(user_input)

      @prompt.say("Bot: #{llm_response}")
    end

    complete_trace if @langfuse

    puts 'Chatbot session ended.'
  rescue Interrupt
    puts 'Chatbot interrupted.'
    complete_trace if @langfuse
  rescue StandardError => e
    puts "Error during chatbot execution: #{e.message}"
    complete_trace if @langfuse
    raise
  end

  # Generates a response from the LLM based on user input.
  #
  # @param user_input [String] The user's input.
  # @return [String] The LLM's response.
  def generate_llm_response(user_input)
    Time.now
    # Create a Langfuse span for the LLM call
    span = @trace&.span(name: 'llm-call', input: { user_input: user_input }) if @trace

    begin
      response = @llm.chat(messages: [{ role: 'user', content: user_input }])
      end_time = Time.now

      span&.update(output: { llm_response: response.dig(:choices, 0, :message, :content) }, end_time: end_time)

      response.dig(:choices, 0, :message, :content)
    rescue StandardError => e
      span&.update(status_message: e.message, level: 'ERROR') if span
      raise
    ensure
      span&.end
    end
  end

  # Completes the Langfuse trace.
  #
  # @return [void]
  def complete_trace
    @trace.end
    puts 'Completed Langfuse trace.'
  end

  # Handles errors and cleans up resources.
  #
  # @return [void]
  def cleanup
    # Add any necessary cleanup operations here
    @langfuse&.shutdown
  end
end

# Example usage:
if __FILE__ == $PROGRAM_NAME
  # Configure Langfuse (replace with your actual keys)
  langfuse_config = {
    public_key: ENV.fetch('LANGFUSE_PUBLIC_KEY', nil),
    secret_key: ENV.fetch('LANGFUSE_SECRET_KEY', nil),
    host: ENV['LANGFUSE_HOST'] || 'https://cloud.langfuse.com'
  }

  chatbot = ChatbotOrchestrator.new(langfuse_config: langfuse_config)
  begin
    chatbot.run_chatbot
  ensure
    chatbot.cleanup
  end
end
