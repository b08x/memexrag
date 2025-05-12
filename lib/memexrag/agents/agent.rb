# frozen_string_literal: true

# The Agent class provides an interface to interact with a language model (LLM),
# using RubyLLM tools and Langfuse for prompt management and observability.
class Agent
  # Initializes a new Agent.
  #
  # @param tools [Array<RubyLLM::Tool, Class>] An array of tool instances or tool classes
  #   that inherit from RubyLLM::Tool. These tools will be registered with the chat
  #   and can be called by the LLM when needed.
  # @param model [String, nil] The model to use for the chat. If nil, uses RubyLLM's default.
  # @param langfuse_client [LangfuseClient::Client, nil] An optional Langfuse client
  #   for fetching managed prompts and logging.
  def initialize(tools: [], model: nil, langfuse_client: nil)
    # Initialize the chat with the specified model if provided
    @chat = model ? RubyLLM.chat(model: model) : RubyLLM.chat
    @langfuse_client = langfuse_client
    @tools = []

    # Register tools with the chat if any are provided
    if tools.any?
      @chat.with_tools(tools)
      @tools = tools.dup
    end

    # Called just before the API request for an assistant message starts
    @chat.on_new_message do
      puts 'Assistant is thinking...'
    end

    # Called after the complete assistant message is received
    @chat.on_end_message do |message|
      if message && message.output_tokens
        puts "\nResponse complete! Used #{message.input_tokens + message.output_tokens} tokens"
      else
        puts "\nResponse complete!"
      end
    end

    # Set up tool-specific event handlers if available
    setup_tool_handlers
  end

  # Asks a question to the LLM.
  #
  # This method can use a direct prompt string or fetch a prompt from Langfuse
  # if a `prompt_name` and `langfuse_client` are provided.
  # It streams the response, printing chunks as they are received.
  # If tools are registered with the chat, the LLM may decide to call them based on the prompt.
  #
  # @param prompt [String] The direct prompt string to use if a Langfuse prompt is not found or specified.
  # @param prompt_name [String, nil] The name of the prompt to fetch from Langfuse.
  # @param prompt_version [Integer, String, nil] The version of the Langfuse prompt to fetch.
  #   Defaults to the latest version if nil.
  # @param prompt_label [String, nil] The label (e.g., "production", "staging") of the Langfuse prompt to fetch.
  # @param prompt_variables [Hash] A hash of variables to compile the Langfuse prompt with.
  # @return [RubyLLM::Message] The final message from the LLM.
  def ask(prompt, prompt_name: nil, prompt_version: nil, prompt_label: nil, prompt_variables: {})
    puts 'Assistant:'

    # Determine the actual prompt to use (direct or from Langfuse)
    actual_prompt = prompt
    if prompt_name && @langfuse_client
      begin
        langfuse_prompt = @langfuse_client.get_prompt(name: prompt_name, version: prompt_version, label: prompt_label)
        # Compile the prompt with variables if provided
        actual_prompt = langfuse_prompt.compile(prompt_variables)
      rescue LangfuseClient::NotFoundError
        puts "Warning: Langfuse prompt '#{prompt_name}' not found. Falling back to direct prompt."
      rescue StandardError => e
        puts "Error fetching Langfuse prompt: #{e.message}. Falling back to direct prompt."
      end
    end

    # Send the prompt to the LLM and stream the response
    # The LLM will automatically call tools if needed based on the conversation
    @chat.ask(actual_prompt) do |chunk|
      # Only print content chunks (not tool calls)
      print chunk.content if chunk.content
    end

    # Return the final message
  end

  # Adds a new tool to the chat.
  #
  # @param tool [RubyLLM::Tool, Class] A tool instance or tool class that inherits from RubyLLM::Tool.
  # @return [void]
  def add_tool(tool)
    @chat.with_tool(tool)
    @tools << tool
  end

  # Returns the list of registered tools.
  #
  # @return [Array<RubyLLM::Tool>] The list of tools registered with the chat.
  def tools
    @tools.dup
  end

  private

  # Sets up tool-specific event handlers if RubyLLM supports them.
  #
  # @return [void]
  def setup_tool_handlers
    # Check if the chat object responds to these methods before setting up handlers
    if @chat.respond_to?(:on_tool_call_start)
      @chat.on_tool_call_start do |tool_call|
        puts "Tool call started: #{tool_call.name}"
      end
    end

    if @chat.respond_to?(:on_tool_call_end)
      @chat.on_tool_call_end do |tool_call, result|
        puts "Tool call ended: #{tool_call.name} with result: #{result}"
      end
    end

    return unless @chat.respond_to?(:on_tool_call_error)

    @chat.on_tool_call_error do |tool_call, error|
      puts "Tool call error: #{tool_call.name} - #{error}"
    end
  end
end

# Example usage:
# # Define a tool that inherits from RubyLLM::Tool
# class WeatherTool < RubyLLM::Tool
#   description "Gets current weather for a location"
#   param :latitude, desc: "Latitude (e.g., 52.5200)"
#   param :longitude, desc: "Longitude (e.g., 13.4050)"
#
#   def execute(latitude:, longitude:)
#     # Implementation to fetch weather data
#     "Weather data for coordinates (#{latitude}, #{longitude})"
#   end
# end
#
# # Set up Langfuse client if needed
# langfuse_config = { public_key: "pk-...", secret_key: "sk-...", host: "http://..." }
# langfuse_client = LangfuseClient::Client.new(langfuse_config)
#
# # Create the agent with tools and model
# agent = Agent.new(
#   tools: [WeatherTool.new],
#   model: 'gpt-4o', # Use a model that supports tools
#   langfuse_client: langfuse_client
# )
#
# # Ask a question that might trigger tool use
# agent.ask("What's the weather like in Berlin? (Lat: 52.52, Long: 13.40)")
#
# # Add another tool later if needed
# class DocumentSearch < RubyLLM::Tool
#   # Tool implementation...
# end
# agent.add_tool(DocumentSearch.new(database))
#
# # Using a Langfuse prompt (if langfuse_client was provided)
# # agent.ask("fallback prompt", prompt_name: "your_prompt_name_in_langfuse")
