# frozen_string_literal: true

# The Agent class provides an interface to interact with a language model (LLM),
# using RubyLLM tools and Langfuse for prompt management and observability.
class Agent
  # Initializes a new Agent.
  #
  # @param prompt_object [LangfuseClient::Prompt] The pre-fetched Langfuse prompt object
  #   that the agent will use for its primary instruction or system prompt.
  # @param tools [Array<RubyLLM::Tool, Class>] An array of tool instances or tool classes
  #   that inherit from RubyLLM::Tool. These tools will be registered with the chat
  #   and can be called by the LLM when needed.
  # @param model [String, nil] The model to use for the chat. If nil, uses RubyLLM's default.
  def initialize(prompt_object:, tools: [], model: nil)
    # Initialize the chat with the specified model if provided
    @chat = model ? RubyLLM.chat(model: model) : RubyLLM.chat
    @prompt_object = prompt_object
    @tools = []

    # Register tools with the chat if any are provided
    if tools.any?
      @chat.with_tools(tools)
      @tools = tools.dup
    end

    # Set up event handlers
    setup_event_handlers

    # Set up tool-specific event handlers if available
    setup_tool_handlers
  end

  # Sets up basic event handlers for the chat
  #
  # @return [void]
  def setup_event_handlers
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
  end

  # Asks a question to the LLM using the agent's initialized prompt object.
  #
  # It compiles the `LangfuseClient::Prompt` object (provided during initialization)
  # with the given `prompt_variables` and sends it to the LLM.
  # The method streams the response, printing content chunks as they are received.
  # If tools are registered with the chat, the LLM may decide to call them based on the prompt.
  #
  # @param prompt_variables [Hash] A hash of variables to compile the agent's
  #   `LangfuseClient::Prompt` object with.
  # @return [RubyLLM::Message] The final message from the LLM.
  # @raise [StandardError] If the agent was not initialized with a valid prompt object.
  def ask(prompt_variables: {})
    puts 'Assistant:'

    raise StandardError, 'Agent not initialized with a valid LangfuseClient::Prompt object that responds to :compile.' unless @prompt_object && @prompt_object.respond_to?(:compile)

    # Compile the prompt object with variables
    begin
      actual_prompt_content = @prompt_object.compile(prompt_variables)
    rescue StandardError => e
      # Handle potential errors during prompt compilation (e.g., missing variables)
      raise StandardError, "Error compiling Langfuse prompt: #{e.message}"
    end

    # Send the compiled prompt content to the LLM and stream the response
    # The LLM will automatically call tools if needed based on the conversation
    @chat.ask(actual_prompt_content) do |chunk|
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
# # --- Code that uses the Agent ---
# # (Assume langfuse_client is configured and available externally,
# # and LangfuseClient::Prompt is defined. The following is a MOCK.)
# #
# # module LangfuseClient
# #   class Prompt
# #     attr_reader :name, :version
# #     def initialize(name:, version:, content_template:)
# #       @name = name
# #       @version = version
# #       @content_template = content_template
# #     end
# #
# #     def compile(variables = {})
# #       compiled_content = @content_template.dup
# #       variables.each { |key, value| compiled_content.gsub!("{#{key}}", value.to_s) }
# #       compiled_content
# #     end
# #   end
# # end
# #
# # # External code would typically fetch the prompt object:
# # # langfuse_client = LangfuseClient::Client.new(...)
# # # weather_prompt_object = langfuse_client.get_prompt(name: "weather_assistant_prompt")
# # # For this example, we'll create a mock prompt object:
# # weather_prompt_object = LangfuseClient::Prompt.new(
# #   name: "weather_assistant_prompt",
# #   version: 1,
# #   content_template: "What is the weather like in {location}?"
# # )
# #
# # # Create the agent with the pre-fetched prompt object
# # agent = Agent.new(
# #   prompt_object: weather_prompt_object,
# #   tools: [WeatherTool.new],
# #   model: 'gpt-4o' # Use a model that supports tools
# # )
# #
# # # Ask a question using the agent's initialized prompt object and variables
# # agent.ask(prompt_variables: { location: "Berlin" })
# #
# # # Example of another prompt object
# # # another_prompt_object = LangfuseClient::Prompt.new(
# # #   name: "greeting_prompt",
# # #   version: 1,
# # #   content_template: "Greet {name} warmly."
# # # )
# # # agent_greeting = Agent.new(prompt_object: another_prompt_object, model: 'gpt-4o')
# # # agent_greeting.ask(prompt_variables: { name: "Alice" })
# #
# # # Add another tool later if needed
# # class DocumentSearch < RubyLLM::Tool
# #   # Tool implementation...
# # end
# # agent.add_tool(DocumentSearch.new(database))
