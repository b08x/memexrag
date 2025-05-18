# frozen_string_literal: true

require 'tty-prompt'
require 'json'

module MemexRAG
  module Commands
    class ConverseCommand < BaseCommand
      include Logging

      SESSION_TYPES = {
        default_rag: {
          name: '📄 Document Q&A (Default RAG)',
          description: 'Ask questions about your documents using the default RAG setup.',
          system_prompt_strategy: :default_system_prompt_for_rag, # Corrected method name
          tools: [:semantic_search]
        },
        langfuse_rag: {
          name: '🗣️ Document Q&A (Custom Langfuse RAG Prompt)',
          description: 'Ask questions about your documents using a specified Langfuse system prompt for RAG.',
          system_prompt_strategy: :fetch_from_langfuse_interactive,
          tools: [:semantic_search]
        },
        general_chat: {
          name: '💬 General Assistant (No RAG)',
          description: 'A general-purpose AI assistant without document searching.',
          system_prompt_strategy: :general_assistant_prompt,
          tools: []
        }
      }.freeze

      def self.command_name
        'converse' # memexrag converse
      end

      def self.description
        'Start an interactive chat session with a choice of AI assistant types.'
      end

      def initialize(options)
        super
        @prompt = TTY::Prompt.new(interrupt: :exit)
        @available_tools = {
          semantic_search: nil # Will be initialized if needed
        }
      end

      def execute(*_args)
        puts 'Welcome to MemexRAG Interactive Chat!'

        choices = SESSION_TYPES.map { |key, config| { name: config[:name], value: key } }
        choices << { name: '🚪 Exit"', value: :exit }

        session_key = @prompt.select('Choose a chat session type:', choices, cycle: true, per_page: 5)
        return if session_key == :exit

        selected_session_config = SESSION_TYPES[session_key]
        launch_chat_session(selected_session_config)
      end

      private

      def launch_chat_session(config)
        # Determine LLM model (CLI option overrides session default, then global default)
        model_name = @options[:model] || config[:default_model] || RubyLLM.config.default_model || 'gpt-4o'
        logger.info "Launching chat session: '#{config[:name]}' with model: #{model_name}"

        chat_instance = RubyLLM.chat(model: model_name)

        # Determine and set the system prompt
        system_instructions = get_system_prompt(config)
        chat_instance.with_instructions(system_instructions)
        logger.info "System prompt set for '#{config[:name]}'."
        # logger.debug "System prompt for '#{config[:name]}': #{system_instructions.slice(0,150)}..."

        # Initialize and register tools
        active_tools = []
        config[:tools].each do |tool_key|
          tool_instance = initialize_tool(tool_key)
          next unless tool_instance

          chat_instance.with_tool(tool_instance)
          active_tools << tool_key.to_s
          logger.info "Tool '#{tool_key}' registered for session '#{config[:name]}'."
        end

        puts "\nStarting '#{config[:name]}'."
        puts "Model: #{model_name}."
        puts "Tools active: #{active_tools.join(', ').empty? ? 'None' : active_tools.join(', ')}."
        puts "Type 'exit' or 'quit' to end this session."
        puts '-' * 50

        run_interactive_chat_loop(chat_instance, active_tools)
      end

      def initialize_tool(tool_key)
        # Cache tool instances for the command's lifetime if they might be reused
        # or always create new if they have per-session state (MemexRAG::Tools::SemanticSearch is stateless for execute)
        case tool_key
        when :semantic_search
          @available_tools[:semantic_search] ||= MemexRAG::Tools::SemanticSearch.new
        # Add other tools here
        # when :spacy_nlp
        #   @available_tools[:spacy_nlp] ||= MemexRAG::Tools::SpacyNLP.new
        else
          logger.warn "Attempted to initialize unknown tool: #{tool_key}"
          nil
        end
      rescue StandardError => e
        logger.error "Failed to initialize tool '#{tool_key}': #{e.message}"
        puts "Warning: Could not initialize tool '#{tool_key}'. It will be unavailable."
        nil
      end

      def get_system_prompt(config)
        # Use strategy from config
        send(config[:system_prompt_strategy])
      rescue StandardError => e
        logger.error "Error resolving system prompt strategy '#{config[:system_prompt_strategy]}': #{e.message}. Falling back."
        default_system_prompt_for_rag # A safe fallback
      end

      def fetch_from_langfuse_interactive
        # These options for langfuse prompt details can be passed to the main 'converse' command
        # and will be available in @options. If not provided, TTY::Prompt asks for them.
        prompt_name = @options[:langfuse_prompt_name] || @prompt.ask('Enter Langfuse prompt name for system instructions:', required: true)
        prompt_version = @options[:langfuse_prompt_version]&.to_i # Optional CLI
        prompt_label = @options[:langfuse_prompt_label]           # Optional CLI

        logger.info "Attempting to fetch Langfuse prompt: Name=#{prompt_name}, Version=#{prompt_version || 'latest'}, Label=#{prompt_label || 'none'}"

        # Identical logic to previous ChatCommand#determine_system_prompt's Langfuse part
        begin
          langfuse_client = ::LangfuseClient::Client.new # Assumes ENV vars are set
          langfuse_prompt_obj = langfuse_client.get_prompt(
            name: prompt_name,
            version: prompt_version,
            label: prompt_label
          )
          content = langfuse_prompt_obj.prompt_content
          if content.is_a?(Array) && content.first&.is_a?(Hash) && content.first[:role]&.to_s == 'system'
            logger.info "Using content from the first system message of Langfuse chat prompt '#{prompt_name}'."
            content.first[:content].to_s
          elsif content.is_a?(String)
            logger.info "Successfully fetched and using Langfuse text prompt '#{prompt_name}'."
            content
          else
            logger.warn "Langfuse prompt '#{prompt_name}' has unexpected content format. Falling back. Content: #{content.inspect}"
            default_system_prompt_for_rag
          end
        rescue LangfuseClient::NotFoundError
          logger.warn "Langfuse prompt '#{prompt_name}' not found. Falling back."
          @prompt.warn("Prompt '#{prompt_name}' not found in Langfuse. Using default RAG prompt.")
          default_system_prompt_for_rag
        rescue LangfuseClient::Error, PyCall::PyError, StandardError => e
          logger.error "Error fetching/using Langfuse prompt '#{prompt_name}': #{e.message}. Falling back."
          @prompt.error("Could not fetch prompt from Langfuse: #{e.message}. Using default RAG prompt.")
          default_system_prompt_for_rag
        end
      end

      def default_system_prompt_for_rag(trail_summary = '')
        tool_class = MemexRAG::Tools::SemanticSearch # Reference the class directly
        tool_description = tool_class.description.gsub(/\s+/, ' ').strip

        # Corrected parameter description generation
        tool_params_description = tool_class.parameters.map do |param_obj| # param_obj is an instance of RubyLLM::Parameter

          name_symbol, details_obj = param_obj # param_obj is one [key, value] from the map iteration
          # where key is the name and value is the Parameter object.

          param_info = "- #{name_symbol} (#{details_obj.type}" # Access attributes via methods
          param_info += ', required' if details_obj.required # Use predicate method

          # Check if default is present. `RubyLLM::Parameter` should have a `default` attribute.
          if !details_obj.required && !details_obj.default.nil? # Check if default is not nil
            param_info += ", optional, default: #{details_obj.default}"
          elsif !details_obj.required
            param_info += ', optional'
          end

          param_info += "): #{details_obj.description}"
          param_info
        end.join("\n          ")

        # ... (rest of the prompt construction as before)
        base_prompt = <<~PROMPT
          You are a helpful AI assistant for the MemexRAG system, specializing in answering questions based on a collection of documents.
          You have access to a powerful tool called 'MemexRAG::Tools::SemanticSearch' to find information within these documents.

          **Tool Available:**
          - **Name:** `MemexRAG::Tools::SemanticSearch` (You can call this as 'SemanticSearch')
          - **Description:** #{tool_description}
          - **Parameters:**
            #{tool_params_description}

          **Your Task:** (Standard RAG instructions from before)
          1. When the user asks a question, first determine if the answer likely resides within the available documents.
          2. If so, formulate an effective search query based on the user's question and use the 'SemanticSearch' tool to find relevant documents.
          3. Analyze the search results provided by the tool.
          4. Synthesize the information from the relevant documents to provide a comprehensive answer to the user's original question.
          5. If you use information from a document, clearly state that the information comes from the documents and, if possible, mention the document ID(s).
          6. If the search tool returns no relevant documents or the documents do not contain the answer, state that clearly. Do not invent information.
          7. For general questions not requiring document search, you may answer directly. Prioritize document search for specific information retrieval.
        PROMPT

        full_prompt = base_prompt
        full_prompt += "\n\nRECENT TRAIL (for context continuity):\n#{trail_summary}" unless trail_summary.to_s.strip.empty?

        full_prompt
      end

      def general_assistant_prompt
        @options[:langfuse_prompt_name] ? fetch_from_langfuse_interactive : 'You are a helpful and friendly general-purpose AI assistant. You do not have access to any specific document search tools in this mode.'
      end

      def run_interactive_chat_loop(chat_instance, active_tools)
        loop do
          user_input = @prompt.ask('You: ')
          break if user_input.nil?

          user_input.strip!
          break if %w[exit quit].include?(user_input.downcase)
          next if user_input.empty?

          if active_tools.empty? && user_input.match?(/\b(search|find|document|look up|what does the doc say about)\b/i)
            puts "Assistant: I don't have document search capabilities in this chat mode."
            next
          end

          spinner = TTY::Spinner.new('Assistant is thinking [:spinner]...', format: :pulse_2)
          spinner.auto_spin

          begin
            response = chat_instance.ask(user_input)
            spinner.success(' ') # Done with a space to clear spinner line
            puts "\nAssistant: #{response.content}"
            logger.info "LLM used tools: #{response.tool_calls.map { |tc| tc[:name] }.join(', ')}" if response.tool_calls && !response.tool_calls.empty?
          rescue RubyLLM::Error, LangfuseClient::Error, StandardError => e
            spinner.error(' (Error)')
            error_message = case e
                            when RubyLLM::Error then "LLM processing error: #{e.message}"
                            when LangfuseClient::Error then "Prompt system error: #{e.message}"
                            else "Unexpected error: #{e.message}"
                            end
            puts "\nAssistant: I'm sorry, an issue occurred. #{error_message}"
            logger.error "Error in chat loop: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
          end
          puts '-' * 50
        end
        puts 'Exiting this chat session.'
      end
    end
  end
end
