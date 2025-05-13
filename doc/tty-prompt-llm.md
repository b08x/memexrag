---
layout: post
title: "RubyLLM Interaction && TTY::Prompt"
date: 2025-04-21 08:04:31 -0400
category:
author:
tags: []
description: ""
related_posts: true
giscus_comments: true
tabs: true
toc: true
---

When designing an LLM client, the primary goal is to facilitate a smooth, engaging conversation between the user and the language model. The interface should be intuitive, responsive, and capable of handling the nuances of text-based interaction. [TTY::Prompt](https://github.com/piotrmurach/tty-prompt) offers a rich set of tools to achieve this, allowing us to create a dynamic and user-friendly command-line experience.

[RubyLLM](https://rubyllm.com/) provides a unified, Ruby-like interface to work with various AI models, making it an excellent choice for our application. To create an engaging and intuitive user interface, we'll leverage `TTY::Prompt`, a powerful library for building interactive command-line applications. But we won't stop at just basic interactions—let's explore creative uses of `TTY::Prompt` that facilitate innovative conversations between multiple LLMs and the user.

## Mapping the Technical Domain: Understanding the Interaction Landscape

Our LLM client needs to handle several core interactions:

1. **User Input**: Collecting prompts and queries from the user.
2. **Model Response**: Displaying the LLM's responses in a readable format.
3. **Context Management**: Maintaining the context of the conversation for coherent multi-turn interactions.
4. **Configuration**: Allowing users to set parameters like temperature, max tokens, and stop sequences.
5. **Feedback Loop**: Providing users with options to rate or react to the LLM's responses, helping improve the model's performance over time.

Beyond these basics, we'll explore creative scenarios where multiple LLMs interact with each other and the user, creating dynamic and engaging experiences.

## Analyzing the Implementation: `TTY::Prompt` and `RubyLLM` in Action

Let's walk through how we can use `TTY::Prompt` and `RubyLLM` to build our LLM client and implement creative use cases:

1. **Initial Setup**:

   ```ruby
   require 'tty-prompt'
   require 'ruby_llm'

   prompt = TTY::Prompt.new
   RubyLLM.configure do |config|
     config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
     # Add keys for other providers as needed
   end
   chat = RubyLLM.chat
   ```

2. **Collecting User Input**:
   We start by asking the user for their initial prompt. `TTY::Prompt` makes this straightforward:

   ```ruby
   user_prompt = prompt.ask('Enter your prompt:')
   ```

3. **Sending the Prompt to the LLM**:
   We send the user's input to the LLM and capture the response using `RubyLLM`:

   ```ruby
   response = chat.ask(user_prompt)
   ```

4. **Displaying the LLM's Response**:
   We present the LLM's response to the user. `TTY::Prompt` can help format this nicely:

   ```ruby
   prompt.say("LLM Response:")
   prompt.say(response)
   ```

5. **Multi-Turn Conversation**:
   To maintain context across multiple turns, we can use a loop that keeps track of the conversation history:

   ```ruby
   conversation_history = []

   loop do
     user_prompt = prompt.ask('Enter your next prompt (or type "exit" to quit):')
     break if user_prompt.downcase == 'exit'

     conversation_history << user_prompt
     response = chat.ask(conversation_history.join('\n'))
     conversation_history << response

     prompt.say("LLM Response:")
     prompt.say(response)
   end
   ```

6. **Configuring LLM Parameters**:
   `TTY::Prompt` allows us to create sophisticated configuration interfaces. For example, setting the temperature parameter:

   ```ruby
   temperature = prompt.slider('Set the temperature:', min: 0, max: 2, step: 0.1, default: 0.7)
   chat.temperature = temperature
   ```

7. **Feedback Loop**:
   We can ask users to rate the LLM's responses to gather feedback:

   ```ruby
   rating = prompt.select('Rate the response:', %w(Excellent Good Fair Poor))
   ```

### Configuring LLM Parameters with `TTY::Prompt` Sliders

`TTY::Prompt` allows us to create sophisticated configuration interfaces using sliders. Sliders are particularly useful for adjusting parameters that have a range of values, such as temperature, max tokens, and other settings that influence the behavior of the LLM. Let's explore various settings that could be adjusted with the slider function:

#### 1. **Temperature**

The temperature parameter controls the randomness of the LLM's output. A higher temperature makes the output more creative and varied, while a lower temperature makes it more deterministic and predictable.

**Implementation:**

```ruby
temperature = prompt.slider('Set the temperature:', min: 0, max: 2, step: 0.1, default: 0.7)
chat.temperature = temperature
prompt.say("Temperature set to: #{temperature}")
```

#### 2. **Max Tokens**

The max tokens parameter limits the length of the LLM's response. Adjusting this parameter allows users to control how much text the LLM generates in a single response.

**Implementation:**

```ruby
max_tokens = prompt.slider('Set the max tokens:', min: 1, max: 4096, step: 1, default: 150)
chat.max_tokens = max_tokens
prompt.say("Max tokens set to: #{max_tokens}")
```

#### 3. **Top P (Nucleus Sampling)**

Top P, or nucleus sampling, is another parameter that controls the diversity of the LLM's output. It determines the cumulative probability of the most likely tokens to consider for generation.

**Implementation:**

```ruby
top_p = prompt.slider('Set the top P:', min: 0, max: 1, step: 0.01, default: 0.9)
chat.top_p = top_p
prompt.say("Top P set to: #{top_p}")
```

#### 4. **Frequency Penalty**

The frequency penalty parameter reduces the likelihood of the LLM repeating the same tokens. This is useful for generating more varied and less repetitive text.

**Implementation:**

```ruby
frequency_penalty = prompt.slider('Set the frequency penalty:', min: 0, max: 2, step: 0.1, default: 0)
chat.frequency_penalty = frequency_penalty
prompt.say("Frequency penalty set to: #{frequency_penalty}")
```

#### 5. **Presence Penalty**

The presence penalty parameter reduces the likelihood of the LLM generating new instances of tokens that have already appeared in the conversation. This helps to keep the conversation fresh and avoid repetition.

**Implementation:**

```ruby
presence_penalty = prompt.slider('Set the presence penalty:', min: 0, max: 2, step: 0.1, default: 0)
chat.presence_penalty = presence_penalty
prompt.say("Presence penalty set to: #{presence_penalty}")
```

#### 6. **Stop Sequences**

Stop sequences are specific strings that, when generated, signal the LLM to stop producing further output. While not a slider, it's a crucial parameter that can be configured using `TTY::Prompt`.

**Implementation:**

```ruby
stop_sequences = prompt.ask('Enter stop sequences (comma-separated):', default: '["\\n", " Human:", " AI:"]')
chat.stop_sequences = stop_sequences.split(',').map(&:strip)
prompt.say("Stop sequences set to: #{chat.stop_sequences.join(', ')}")
```

## Creative Uses of `TTY::Prompt` for LLM Interactions

Now, let's dive into some creative use cases that leverage `TTY::Prompt` to facilitate interactions between multiple LLMs and the user:

## 1. **LLM Debate Forum**

Create a debate forum where two or more LLMs discuss a topic, and the user can intervene, moderate, or ask follow-up questions.

**Implementation:**

1. **Select Participants**:

   ```ruby
   llms = ["LLM1", "LLM2", "LLM3"]
   selected_llms = prompt.multi_select('Select LLMs to participate in the debate:', llms)
   ```

2. **Topic Selection**:

   ```ruby
   topic = prompt.ask('Enter the debate topic:')
   ```

3. **Debate Loop**:

   ```ruby
   loop do
     selected_llms.each do |llm|
       response = RubyLLM.chat(llm).ask("Debate on: #{topic}")
       prompt.say("#{llm}: #{response}")
     end
     user_intervention = prompt.ask('Do you want to intervene or ask a follow-up question? (yes/no):')
     break unless user_intervention.downcase == 'yes'
     follow_up = prompt.ask('Enter your follow-up question:')
     selected_llms.each do |llm|
       response = RubyLLM.chat(llm).ask(follow_up)
       prompt.say("#{llm}: #{response}")
     end
   end
   ```

## 2. **Collaborative Storytelling**

Engage multiple LLMs in collaborative storytelling, where each LLM contributes a segment of the story, and the user can guide the narrative.

**Implementation:**

1. **Story Setup**:

   ```ruby
   prompt.say("Welcome to the collaborative storytelling session!")
   story_title = prompt.ask('Enter the title of the story:')
   ```

2. **Story Loop**:

   ```ruby
   story_segments = []
   loop do
     llms.each do |llm|
       next_segment = RubyLLM.chat(llm).ask("Continue the story titled: #{story_title}. Current story: #{story_segments.join(' ')}")
       story_segments << next_segment
       prompt.say("#{llm} contributes: #{next_segment}")
     end
     user_guidance = prompt.ask('Do you want to guide the story? (yes/no):')
     break unless user_guidance.downcase == 'yes'
     guidance = prompt.ask('Enter your guidance for the next segment:')
     story_segments << guidance
   end
   ```

## 3. **Expert Panel Discussion**

Create an expert panel discussion where each LLM acts as an expert in a specific domain, and the user can ask questions to the panel.

**Implementation:**

1. **Select Experts**:

   ```ruby
   experts = { "LLM1" => "AI Ethics", "LLM2" => "Quantum Computing", "LLM3" => "Climate Change" }
   selected_experts = prompt.multi_select('Select experts for the panel:', experts.keys)
   ```

2. **Ask Questions**:

   ```ruby
   loop do
     question = prompt.ask('Enter your question for the panel:')
     selected_experts.each do |expert|
       response = RubyLLM.chat(expert).ask("Question: #{question}. Your expertise: #{experts[expert]}")
       prompt.say("#{expert} (Expert in #{experts[expert]}): #{response}")
     end
     continue = prompt.ask('Do you want to ask another question? (yes/no):')
     break unless continue.downcase == 'yes'
   end
   ```

## 4. **LLM-Driven Quiz Show**

Host a quiz show where one LLM acts as the quizmaster, asking questions, and other LLMs (and the user) act as contestants.

**Implementation:**

1. **Select Quizmaster**:

   ```ruby
   quizmaster = prompt.select('Select the quizmaster:', llms)
   ```

2. **Quiz Loop**:

   ```ruby
   loop do
     question = RubyLLM.chat(quizmaster).ask("Generate a quiz question.")
     prompt.say("Quizmaster #{quizmaster} asks: #{question}")
     contestants = llms - [quizmaster]
     contestants.each do |contestant|
       answer = RubyLLM.chat(contestant).ask("Answer the question: #{question}")
       prompt.say("#{contestant} answers: #{answer}")
     end
     user_answer = prompt.ask('Your answer:')
     prompt.say("Your answer: #{user_answer}")
     continue = prompt.ask('Do you want to continue the quiz? (yes/no):')
     break unless continue.downcase == 'yes'
   end
   ```

## 5. **Interactive LLM Tutorials**

Create interactive tutorials where one LLM acts as the instructor, guiding the user through a topic, and other LLMs provide additional insights or exercises.

**Implementation:**

1. **Select Instructor**:

   ```ruby
   instructor = prompt.select('Select the instructor LLM:', llms)
   ```

2. **Tutorial Loop**:

   ```ruby
   topic = prompt.ask('Enter the topic for the tutorial:')
   loop do
     instruction = RubyLLM.chat(instructor).ask("Provide the next step in the tutorial on: #{topic}")
     prompt.say("Instructor #{instructor}: #{instruction}")
     additional_insights = llms - [instructor]
     additional_insights.each do |insight_llm|
       insight = RubyLLM.chat(insight_llm).ask("Provide additional insights on: #{instruction}")
       prompt.say("#{insight_llm} adds: #{insight}")
     end
     user_question = prompt.ask('Do you have any questions? (yes/no):')
     if user_question.downcase == 'yes'
       question = prompt.ask('Enter your question:')
       answer = RubyLLM.chat(instructor).ask("Answer the question: #{question}")
       prompt.say("Instructor #{instructor} answers: #{answer}")
     end
     continue = prompt.ask('Do you want to continue the tutorial? (yes/no):')
     break unless continue.downcase == 'yes'
   end
   ```

## Evaluating the Architecture: Coherence and Scalability

Using `TTY::Prompt` and `RubyLLM` for these creative LLM interactions aligns well with the Wit Coherence Guidelines:

1. **Complexity**:
   `TTY::Prompt` manages the complexity of user interaction within the Ruby ecosystem. By keeping the interaction logic internal, we avoid the pitfalls of external dependencies and shell scripting. This results in a more maintainable and scalable codebase. `RubyLLM` simplifies working with multiple AI providers, offering a unified API that reduces the complexity of juggling different client libraries and response formats.

2. **Evolution**:
   As the LLM client grows, `TTY::Prompt` provides a smooth path for adding new features. Whether it's more advanced configuration options, multi-step wizards, or sophisticated feedback mechanisms, `TTY::Prompt`'s rich set of features ensures that the application can evolve gracefully. `RubyLLM`'s unified API means that adding support for new AI providers or features is straightforward, ensuring the application can adapt to new requirements with minimal effort.

3. **Implications**:
   The integrated nature of `TTY::Prompt` means that the user experience is seamless and predictable. Dependencies are managed through Bundler, simplifying deployment and ensuring that the application works consistently across different environments. `RubyLLM`'s minimal dependencies and idiomatic Ruby API make it a joy to work with, ensuring that the application remains robust and maintainable.

## Applying Domain Wit: Parallels and Insights

Drawing parallels from other technical domains can provide valuable insights. Consider the evolution of web applications:

* **Early Web Apps**: Initially, web applications were simple, often relying on basic HTML forms and server-side processing. This is akin to using external tools for straightforward interactions.
* **Modern Web Apps**: Today, web applications are rich, interactive experiences powered by JavaScript frameworks like React or Vue.js. These frameworks provide the tools needed to build complex, dynamic user interfaces – much like how `TTY::Prompt` enables rich interactions in a command-line application.

By embracing `TTY::Prompt` and `RubyLLM`, we're following a similar evolutionary path, moving from simple, external tools to integrated, powerful libraries that enable complex, user-friendly interactions.

## Providing Sources and Documentation

To implement these creative uses effectively, you'll want to dive into the documentation and examples provided by `TTY::Prompt` and `RubyLLM`. Here are some resources to get you started:

* **`TTY::Prompt` Documentation**: [https://github.com/piotrmurach/tty-prompt](https://github.com/piotrmurach/tty-prompt)
* **`RubyLLM` Documentation**: [https://rubyllm.com](https://rubyllm.com)
