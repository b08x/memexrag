# LangfuseClient

A Ruby interface to the Langfuse Python SDK for LLM prompt management.

## Overview

LangfuseClient provides a Ruby wrapper around the Langfuse Python SDK, allowing Ruby applications to leverage Langfuse's prompt management capabilities. This library enables you to:

- Create and version prompts
- Retrieve prompts by name, version, or label
- List available prompts with filtering options
- Compile prompts with variable substitution
- Manage both text-based and chat-based prompts

## Installation

### Prerequisites

This gem requires:

- Ruby 2.6+
- Python with the Langfuse SDK installed

### Install Python Dependencies

```bash
pip install langfuse
```

### Install the Ruby Gem

Add to your Gemfile:

```ruby
gem 'langfuse_client'
```

Or install directly:

```bash
gem install langfuse_client
```

## Configuration

Configure LangfuseClient with your Langfuse API credentials:

```ruby
require 'langfuse_client'

# Option 1: Pass credentials directly
client = LangfuseClient::Client.new(
  public_key: "your_public_key",
  secret_key: "your_secret_key",
  host: "https://cloud.langfuse.com" # Optional, defaults to this value
)

# Option 2: Use environment variables
# Set LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY environment variables
client = LangfuseClient::Client.new
```

## Working with Prompts

### Create a Prompt

#### Text Prompt

```ruby
text_prompt = client.create_prompt(
  name: "my-text-prompt",
  prompt_content: "Generate a {{topic}} description in {{style}} style.",
  type: LangfuseClient::PROMPT_TYPE_TEXT,
  config: { model: "gpt-4" },
  labels: ["production"],
  tags: ["documentation", "text-generation"],
  commit_message: "Initial prompt version"
)
```

#### Chat Prompt

```ruby
chat_prompt = client.create_prompt(
  name: "my-chat-prompt",
  prompt_content: [
    { role: "system", content: "You are a helpful assistant." },
    { role: "user", content: "Tell me about {{subject}}" }
  ],
  type: LangfuseClient::PROMPT_TYPE_CHAT,
  config: { temperature: 0.7 },
  labels: ["staging"],
  tags: ["conversation"],
  commit_message: "Initial chat prompt"
)
```

### Retrieve a Prompt

```ruby
# Get latest version
prompt = client.get_prompt(name: "my-text-prompt")

# Get specific version
prompt = client.get_prompt(name: "my-text-prompt", version: 2)

# Get by label
prompt = client.get_prompt(name: "my-text-prompt", label: "production")
```

### Check if a Prompt Exists

```ruby
if client.prompt_exists?(name: "my-text-prompt")
  puts "Prompt exists!"
else
  puts "Prompt not found."
end
```

### List Prompts

```ruby
# List all prompts
all_prompts = client.list_prompts

# With filtering
filtered_prompts = client.list_prompts(
  name: "my-prompt",      # Optional name filter
  label: "production",    # Optional label filter
  tags: ["documentation"], # Optional tags filter
  limit: 10,              # Optional limit
  page: 1                 # Optional pagination
)
```

### Using Prompts

Compile a prompt by replacing variables:

```ruby
# For text prompts
compiled_text = prompt.compile(
  topic: "artificial intelligence",
  style: "academic"
)

# For chat prompts
compiled_messages = prompt.compile(
  subject: "machine learning"
)
```

## Error Handling

LangfuseClient provides several error classes for specific error conditions:

```ruby
begin
  client.get_prompt(name: "non-existent-prompt")
rescue LangfuseClient::NotFoundError => e
  puts "Prompt not found: #{e.message}"
rescue LangfuseClient::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue LangfuseClient::InvalidRequestError => e
  puts "Invalid request: #{e.message}"
rescue LangfuseClient::ApiConnectionError => e
  puts "API connection error: #{e.message}"
rescue LangfuseClient::LangfuseApiError => e
  puts "Langfuse API error: #{e.message}"
rescue LangfuseClient::Error => e
  puts "General error: #{e.message}"
end
```

## Prompt Attributes

When working with retrieved prompts, you can access the following attributes:

```ruby
prompt = client.get_prompt(name: "my-text-prompt")

prompt.name           # Prompt name
prompt.version        # Version number
prompt.prompt_content # Content (string for text, array for chat)
prompt.type           # "text" or "chat"
prompt.config         # Configuration hash
prompt.labels         # Array of labels
prompt.tags           # Array of tags
prompt.commit_message # Optional commit message
```

## Advanced Usage

### Access to Python Objects

For advanced use cases, you can access the underlying Python objects:

```ruby
# Access Python client
py_client = client.py_langfuse_client

# Access Python module
py_module = client.langfuse_python_module

# Access raw Python prompt object
py_prompt = prompt.raw_python_object
```

## Troubleshooting

### Common Issues

1. **PyCall Initialization Errors**
   - Ensure Python is in your PATH
   - Verify the Langfuse Python SDK is installed

2. **Authentication Failures**
   - Check your API keys
   - Ensure host URL is correct

3. **Missing Python Dependencies**
   - Run `pip install langfuse` to install the required Python SDK

### Debug Mode

For detailed error messages with Python tracebacks, use the error handling shown above.

## License

[License information goes here]

## Contributing

[Contributing information goes here]
