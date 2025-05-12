require_relative '../clients/langfuse_client'

class Agent
  def initialize(tools: {}, langfuse_client: nil)
    @chat = RubyLLM.chat
    @tools = tools
    @langfuse_client = langfuse_client

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

    # Add tool-specific event handlers if needed
    setup_tool_handlers if @tools.any?
  end

  # Ask a question using either a direct prompt or a named prompt from Langfuse
  def ask(prompt, prompt_name: nil, prompt_version: nil, prompt_label: nil, prompt_variables: {})
    puts 'Assistant:'

    # If a prompt_name is provided and we have a langfuse_client, try to fetch the prompt
    if prompt_name && @langfuse_client
      begin
        langfuse_prompt = @langfuse_client.get_prompt(name: prompt_name, version: prompt_version, label: prompt_label)
        # Compile the prompt with variables if provided
        compiled_prompt = langfuse_prompt.compile(prompt_variables)

        # Use the compiled prompt instead of the direct prompt
        @chat.ask compiled_prompt do |chunk|
          print chunk.content # Print content fragment immediately
        end
      rescue LangfuseClient::NotFoundError
        puts "Warning: Langfuse prompt '#{prompt_name}' not found. Falling back to direct prompt."
        @chat.ask prompt do |chunk|
          print chunk.content
        end
      rescue StandardError => e
        puts "Error fetching Langfuse prompt: #{e.message}. Falling back to direct prompt."
        @chat.ask prompt do |chunk|
          print chunk.content
        end
      end
    else
      # Use the direct prompt if no prompt_name is provided or langfuse_client is not available
      @chat.ask prompt do |chunk|
        print chunk.content
      end
    end
  end

  def use_tool(tool_name, arguments)
    tool = @tools[tool_name]
    raise "Tool not found: #{tool_name}" unless tool

    tool.call(arguments)
  end

  private


  def setup_tool_handlers
    # If we need specific tool event handling, we can implement it here
    # This keeps the tool-specific event handling separate from the main message handlers

    # Example of how we might handle tool events if RubyLLM supports them:
    # @chat.on_tool_call_start do |tool_call|
    #   puts "Tool call started: #{tool_call.name}"
    # end

    # @chat.on_tool_call_end do |tool_call, result|
    #   puts "Tool call ended: #{tool_call.name} with result: #{result}"
    # end

    # @chat.on_tool_call_error do |tool_call, error|
    #   puts "Tool call error: #{tool_call.name} - #{error}"
    # end
  end
end

# Example usage:
# langfuse_config = { public_key: "pk-...", secret_key: "sk-...", host: "http://..." }
# langfuse_client = LangfuseClient::Client.new(langfuse_config)
# agent = Agent.new(langfuse_client: langfuse_client)
#
# # Using a direct prompt
# agent.ask("What is Ruby?")
#
# # Using a Langfuse prompt (if langfuse_client was provided)
# agent.ask("fallback prompt", prompt_name: "Steve")
#
# # To list available prompts, use the client directly:
# # prompts = langfuse_client.list_prompts
