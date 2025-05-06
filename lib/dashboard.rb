require 'sinatra'
require 'slim'


set :views, File.expand_path('views', __dir__)

get '/' do
  @agents = Agent.all.to_a
  slim :dashboard
end

# Tasks Route
get '/tasks' do
  @tasks = Task.all.to_a
  slim :tasks
end

# Logs Route
get '/logs' do
  @logs = Log.all.to_a
  slim :logs
end

# Trails Route
get '/trails' do
  @trails = Trail.all.to_a
  slim :trails
end

# Tools Route
get '/tools' do
  @tools = Tool.all.to_a
  slim :tools
end

# Processors Route
get '/processors' do
  @processors = Processor.all.to_a
  slim :processors
end

# Agents Route
get '/agents' do
  @agents = Agent.all.to_a
  slim :agents
end

# Bots Route
get '/bots' do
  @bots = Bot.all.to_a
  slim :bots
end
