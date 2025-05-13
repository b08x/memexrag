# Building Chatbots with RubyLLM and LangfuseClient

This guide demonstrates how to create powerful, customized chatbots by combining RubyLLM for model interactions with LangfuseClient for prompt management.

## Core Integration Concepts

- **Prompt Management**: Use LangfuseClient to version, store, and retrieve optimized prompts
- **Conversation Flow**: Use RubyLLM for handling multi-turn conversations
- **Rich Media Support**: Leverage RubyLLM's multi-modal capabilities
- **Instrumentation**: Track performance across both systems

## Installation

```ruby
# Add to your Gemfile
gem 'ruby_llm'
gem 'langfuse_client'

# Or install directly
gem install ruby_llm
gem install langfuse_client
```

## Configuration

```ruby
# config/initializers/ai_services.rb
require 'ruby_llm'
require 'langfuse_client'

# Configure RubyLLM
RubyLLM.configure do |config|
  config.openai.api_key = ENV["OPENAI_API_KEY"]
  config.anthropic.api_key = ENV["ANTHROPIC_API_KEY"]
  config.default_model = ENV["DEFAULT_MODEL"] || "gpt-4o"
end

# Configure LangfuseClient
LANGFUSE_CLIENT = LangfuseClient::Client.new(
  public_key: ENV["LANGFUSE_PUBLIC_KEY"],
  secret_key: ENV["LANGFUSE_SECRET_KEY"]
)
```

## Example 1: Customer Support Chatbot

A chatbot with managed, versioned prompts that helps customers resolve issues:

```ruby
class CustomerSupportBot
  attr_reader :chat, :customer

  def initialize(customer_id)
    @customer = Customer.find(customer_id)
    @chat = RubyLLM.chat(model: "claude-3-5-sonnet")
    load_system_prompt
  end

  def load_system_prompt
    # Fetch versioned system prompt from Langfuse
    prompt = LANGFUSE_CLIENT.get_prompt(name: "customer-support-system")
    
    # Compile it with customer data
    instructions = prompt.compile(
      company_name: "Acme Inc.",
      customer_name: @customer.name,
      subscription_tier: @customer.subscription_tier,
      product_names: @customer.purchased_products.join(", ")
    )
    
    # Set as system prompt in RubyLLM
    @chat.with_instructions(instructions)
  end

  def ask(query, with_context: {})
    # Track customer inquiries
    @customer.inquiries.create(content: query)
    
    # Add relevant context from customer history
    context = {
      recent_issues: @customer.issues.recent.map(&:summary).join("\n"),
      account_status: @customer.account_status
    }.merge(with_context)
    
    # Create contextual prompt
    context_prompt = LANGFUSE_CLIENT.get_prompt(name: "customer-query-context")
    contextualized_query = context_prompt.compile(
      query: query,
      context: context.to_json
    )
    
    # Get response from AI
    response = @chat.ask(contextualized_query)
    
    # Track statistics
    @customer.update(
      total_tokens_used: @customer.total_tokens_used + response.input_tokens + response.output_tokens
    )
    
    response
  end

  def handle_product_issue(product_id, issue_description, attachment = nil)
    product = Product.find(product_id)
    
    # Get product-specific troubleshooting prompt
    troubleshoot_prompt = LANGFUSE_CLIENT.get_prompt(
      name: "product-troubleshooting",
      label: product.category
    )
    
    query = troubleshoot_prompt.compile(
      product_name: product.name,
      issue_description: issue_description,
      user_history: @customer.history_with(product).to_json
    )
    
    # Handle image attachments
    if attachment&.image?
      return @chat.ask(query, with: { image: attachment.path })
    else
      return @chat.ask(query)
    end
  end
end

# Usage
bot = CustomerSupportBot.new(customer_id: 123)
response = bot.ask("I'm having trouble connecting my device to WiFi")
puts response.content

# With an image attachment
response = bot.handle_product_issue(
  product_id: 456, 
  issue_description: "Error screen when booting",
  attachment: customer_uploaded_file
)
```

## Example 2: Technical Documentation Assistant

A chatbot for searching and explaining technical documentation:

```ruby
class TechnicalDocsAssistant
  attr_reader :chat, :docs_context

  def initialize(product_slug)
    @product = Product.find_by(slug: product_slug)
    @docs_context = fetch_documentation_context
    @chat = RubyLLM.chat(model: "gpt-4o")
    initialize_assistant
  end

  def initialize_assistant
    # Get base prompt from Langfuse
    base_prompt = LANGFUSE_CLIENT.get_prompt(name: "technical-assistant-base")
    
    # Compile with product-specific information
    instructions = base_prompt.compile(
      product_name: @product.name,
      product_documentation_index: @docs_context[:index].to_json,
      api_reference_version: @product.current_api_version
    )
    
    @chat.with_instructions(instructions)
  end
  
  def fetch_documentation_context
    # Fetch relevant docs and create context
    {
      index: @product.documentation_sections.map(&:title),
      content: @product.documentation_sections.to_h { |s| [s.title, s.content] }
    }
  end

  def answer_question(question)
    # First determine relevant documentation sections
    section_finder_prompt = LANGFUSE_CLIENT.get_prompt(name: "docs-section-finder")
    section_query = section_finder_prompt.compile(
      question: question,
      available_sections: @docs_context[:index].join("\n")
    )
    
    # Get section recommendations
    section_response = RubyLLM.chat.ask(section_query)
    relevant_sections = parse_sections(section_response.content)
    
    # Fetch content for relevant sections
    relevant_content = relevant_sections.map do |section|
      "## #{section}\n#{@docs_context[:content][section]}"
    end.join("\n\n")
    
    # Create answer with relevant documentation
    answer_prompt = LANGFUSE_CLIENT.get_prompt(name: "technical-answer-with-docs")
    final_query = answer_prompt.compile(
      question: question,
      documentation: relevant_content
    )
    
    @chat.ask(final_query)
  end
  
  def explain_code_snippet(code, language = "ruby")
    # Get code explanation prompt
    code_prompt = LANGFUSE_CLIENT.get_prompt(name: "code-explainer")
    query = code_prompt.compile(
      code: code,
      language: language,
      product_context: @product.name
    )
    
    @chat.ask(query)
  end
  
  private
  
  def parse_sections(section_response)
    # Extract section names from model response
    # Implementation depends on expected format from section-finder prompt
    section_response.scan(/- (.+)/).flatten
  end
end

# Usage
docs_bot = TechnicalDocsAssistant.new("api-gateway")
response = docs_bot.answer_question("How do I set up rate limiting?")
puts response.content

code_explanation = docs_bot.explain_code_snippet('''
client = ApiGateway.new(token: ENV["API_KEY"])
client.configure_rate_limit(max_requests: 100, window_seconds: 60)
''')
```

## Example 3: Interview Preparation Coach

A chatbot that helps users prepare for technical interviews:

```ruby
class InterviewCoach
  attr_reader :chat, :session_stats
  
  def initialize(job_role, experience_level = "mid")
    @job_role = job_role
    @experience_level = experience_level
    @chat = RubyLLM.chat(model: "claude-3-5-sonnet")
    @session_stats = { questions_asked: 0, feedback_given: 0 }
    setup_coach
  end
  
  def setup_coach
    # Get role-specific coaching prompt
    coaching_prompt = LANGFUSE_CLIENT.get_prompt(
      name: "interview-coach-system",
      label: @job_role
    )
    
    # Compile with specifics
    instructions = coaching_prompt.compile(
      job_role: @job_role,
      experience_level: @experience_level,
      focus_areas: interview_focus_areas.join(", ")
    )
    
    @chat.with_instructions(instructions)
  end
  
  def interview_focus_areas
    case @job_role
    when "ruby_developer"
      ["Ruby syntax", "Rails architecture", "Testing practices", "Database optimization"]
    when "data_scientist"
      ["Statistical analysis", "ML frameworks", "Data visualization", "Experimental design"]
    else
      ["Technical knowledge", "Problem solving", "Communication skills"]
    end
  end
  
  def next_question
    # Get prompt for generating interview questions
    question_prompt = LANGFUSE_CLIENT.get_prompt(
      name: "interview-question-generator", 
      label: @job_role
    )
    
    query = question_prompt.compile(
      experience_level: @experience_level,
      previous_questions: @chat.messages.select { |m| m.role == :assistant && m.metadata[:type] == "question" }
                                    .map(&:content)
                                    .join("\n\n")
    )
    
    response = @chat.ask(query)
    response.metadata[:type] = "question"  # Tag this message as a question
    @session_stats[:questions_asked] += 1
    
    response
  end
  
  def evaluate_answer(user_answer)
    # Get evaluation prompt
    eval_prompt = LANGFUSE_CLIENT.get_prompt(name: "answer-evaluation")
    
    # Find the most recent question
    last_question = @chat.messages.reverse.find { |m| m.role == :assistant && m.metadata[:type] == "question" }
    
    query = eval_prompt.compile(
      question: last_question.content,
      answer: user_answer,
      experience_level: @experience_level
    )
    
    response = @chat.ask(query)
    response.metadata[:type] = "feedback"  # Tag this message as feedback
    @session_stats[:feedback_given] += 1
    
    response
  end
  
  def generate_study_plan
    # Create personalized study plan based on performance
    plan_prompt = LANGFUSE_CLIENT.get_prompt(name: "study-plan-generator")
    
    # Get all feedback to analyze patterns
    all_feedback = @chat.messages.select { |m| m.role == :assistant && m.metadata[:type] == "feedback" }
                              .map(&:content)
                              .join("\n\n")
    
    query = plan_prompt.compile(
      job_role: @job_role,
      experience_level: @experience_level,
      feedback_history: all_feedback
    )
    
    @chat.ask(query)
  end
end

# Usage
coach = InterviewCoach.new("ruby_developer", "senior")

# Get an interview question
question = coach.next_question
puts "Question: #{question.content}"

# User answers
user_answer = "ActiveRecord callbacks are hooks into the lifecycle of an object..."

# Get feedback on answer
feedback = coach.evaluate_answer(user_answer)
puts "Feedback: #{feedback.content}"

# After several Q&A rounds, generate study plan
study_plan = coach.generate_study_plan
puts "Your Study Plan:\n#{study_plan.content}"
```

## Example 4: Multi-modal Learning Assistant

An educational assistant that can work with images and PDFs:

```ruby
class LearningAssistant
  attr_reader :chat, :subject
  
  def initialize(subject, grade_level)
    @subject = subject
    @grade_level = grade_level
    @chat = RubyLLM.chat(model: "gpt-4o") # For multi-modal capabilities
    configure_assistant
  end
  
  def configure_assistant
    # Get educational prompt tailored to subject
    education_prompt = LANGFUSE_CLIENT.get_prompt(
      name: "educational-assistant",
      label: @subject
    )
    
    instructions = education_prompt.compile(
      subject: @subject,
      grade_level: @grade_level,
      teaching_approach: teaching_approach_for_subject
    )
    
    @chat.with_instructions(instructions)
  end
  
  def teaching_approach_for_subject
    case @subject
    when "mathematics"
      "Use progressive problem-solving with visual examples when possible"
    when "history"
      "Connect historical events to contemporary issues and use storytelling"
    when "science"
      "Emphasize experimental thinking and real-world applications"
    else
      "Use clear explanations with relevant examples"
    end
  end
  
  def explain_concept(concept)
    concept_prompt = LANGFUSE_CLIENT.get_prompt(
      name: "concept-explanation",
      label: @subject
    )
    
    query = concept_prompt.compile(
      concept: concept,
      grade_level: @grade_level
    )
    
    @chat.ask(query)
  end
  
  def explain_diagram(image_path, question = nil)
    # For explaining visual content like math problems, science diagrams
    diagram_prompt = LANGFUSE_CLIENT.get_prompt(name: "diagram-analysis")
    
    question ||= "Explain this #{@subject} diagram in detail at a #{@grade_level} level."
    
    query = diagram_prompt.compile(
      question: question,
      subject: @subject
    )
    
    @chat.ask(query, with: { image: image_path })
  end
  
  def analyze_homework(pdf_path)
    # For reviewing homework PDFs
    homework_prompt = LANGFUSE_CLIENT.get_prompt(name: "homework-analysis")
    
    query = homework_prompt.compile(
      subject: @subject,
      grade_level: @grade_level
    )
    
    @chat.ask(query, with: { pdf: pdf_path })
  end
  
  def generate_practice_problems(topic, difficulty = "medium", count = 3)
    # Generate subject-specific practice problems
    practice_prompt = LANGFUSE_CLIENT.get_prompt(
      name: "practice-problem-generator",
      label: @subject
    )
    
    query = practice_prompt.compile(
      topic: topic,
      difficulty: difficulty,
      count: count,
      grade_level: @grade_level
    )
    
    @chat.ask(query)
  end
  
  def check_answer(problem, student_answer)
    # Evaluate student answers to problems
    evaluation_prompt = LANGFUSE_CLIENT.get_prompt(name: "answer-checker")
    
    query = evaluation_prompt.compile(
      problem: problem,
      student_answer: student_answer,
      subject: @subject,
      grade_level: @grade_level
    )
    
    @chat.ask(query)
  end
end

# Usage
math_assistant = LearningAssistant.new("mathematics", "high school")

# Explain a concept
response = math_assistant.explain_concept("quadratic equations")
puts response.content

# Analyze a diagram or math problem
response = math_assistant.explain_diagram("path/to/parabola_graph.png", 
  "What are the key features of this quadratic function?")
puts response.content

# Check homework
feedback = math_assistant.analyze_homework("path/to/calculus_homework.pdf")
puts feedback.content

# Generate practice problems
problems = math_assistant.generate_practice_problems("derivatives", "challenging", 2)
puts problems.content

# Check a student's answer
feedback = math_assistant.check_answer(
  "Find the derivative of f(x) = x³ - 4x² + 7x - 10",
  "f'(x) = 3x² - 8x + 7"
)
puts feedback.content
```

## Best Practices

### Prompt Management with LangfuseClient

1. **Organize prompts hierarchically**:
   - Base system prompts
   - Context-gathering prompts
   - Response-formatting prompts

2. **Use versioning for iterative improvement**:

   ```ruby
   # After evaluating performance
   improved_prompt = client.create_prompt(
     name: "customer-support-system",
     prompt_content: new_improved_content,
     # Version is automatically incremented
     commit_message: "Improved tone for technical issues"
   )
   ```

3. **Apply consistent labeling**:
   - "production" vs "development"
   - Domain-specific labels (e.g., "mathematics", "history")
   - Usage-specific labels (e.g., "system", "user-context")

### Effective RubyLLM Integration

1. **Model selection based on capabilities**:

   ```ruby
   def select_model_for_task(task_type)
     case task_type
     when :general
       "gpt-4o"
     when :creative
       RubyLLM.chat(model: "claude-3-5-sonnet").with_temperature(0.9)
     when :code
       RubyLLM.chat(model: "claude-3-opus-20240229")
     when :image_analysis
       RubyLLM.chat(model: "gemini-1.5-pro-latest")
     end
   end
   ```

2. **Handle multi-modal content appropriately**:
   - Check model capability before sending images/PDFs
   - Prepare fallback text descriptions

3. **Manage conversation context effectively**:
   - Use custom metadata to track message types
   - Reset context when changing topics

## Deployment Considerations

1. **Environment-specific configurations**:

   ```ruby
   # config/environments/production.rb
   config.after_initialize do
     # Use production-ready models in production
     RubyLLM.configure do |config|
       config.default_model = "gpt-4o"
     end
     
     # Use production-labeled prompts
     PROMPT_LABEL = "production"
   end
   
   # config/environments/development.rb
   config.after_initialize do
     # Use faster/cheaper models in development
     RubyLLM.configure do |config|
       config.default_model = "gpt-3.5-turbo"
     end
     
     # Use development prompts
     PROMPT_LABEL = "development"
   end
   ```

2. **Performance monitoring**:

   ```ruby
   chat.on_end_message do |message|
     if message
       # Log usage metrics
       MetricsService.track_usage(
         model: message.model_id,
         input_tokens: message.input_tokens,
         output_tokens: message.output_tokens
       )
     end
   end
   ```

3. **Error handling**:

   ```ruby
   def resilient_ask(query, retries = 2)
     begin
       @chat.ask(query)
     rescue RubyLLM::RateLimitError => e
       if retries > 0
         sleep(2)
         resilient_ask(query, retries - 1)
       else
         raise e
       end
     rescue RubyLLM::Error => e
       # Log the error
       Rails.logger.error("AI Service Error: #{e.message}")
       # Return graceful fallback response
       OpenStruct.new(content: "I'm sorry, I encountered an error. Please try again shortly.")
     end
   end
   ```

## Summary

By combining RubyLLM's conversation capabilities with LangfuseClient's prompt management, you can create sophisticated, maintainable chatbots that:

- Leverage optimized, versioned prompts
- Handle multi-modal content
- Adapt to different domains and use cases
- Scale effectively in production environments

This integration provides a robust foundation for building AI-powered conversational applications in Ruby.
