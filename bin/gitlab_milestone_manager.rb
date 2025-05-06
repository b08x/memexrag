#!/usr/bin/env ruby
# gitlab_milestone_manager.rb - Manage GitLab milestones

require 'uri'
require 'json'
require 'net/http'
require 'optparse'
require 'date'
require 'fileutils'

options = {
  gitlab_url: ENV['GITLAB_INSTANCE_URL'] || 'https://gitlab.com',
  token: ENV['GITLAB_PRIVATE_TOKEN'],
  action: 'list'
}

OptionParser.new do |opts|
  opts.banner = "Usage: gitlab_milestone_manager.rb [options]"
  
  opts.on("--project-id ID", "GitLab project ID") { |v| options[:project_id] = v }
  opts.on("--token TOKEN", "GitLab API token") { |v| options[:token] = v }
  opts.on("--list", "List all milestones (default action)") { options[:action] = 'list' }
  opts.on("--create TITLE", "Create a new milestone") { |v| options[:title] = v; options[:action] = 'create' }
  opts.on("--description TEXT", "Description for new milestone") { |v| options[:description] = v }
  opts.on("--due-date DATE", "Due date for new milestone (YYYY-MM-DD)") { |v| options[:due_date] = v }
  opts.on("--export [FILE]", "Export milestone IDs to config file") { |v| options[:export_file] = v || '.gitlab_milestones.json'; options[:action] = 'export' }
  opts.on("--create-project-milestones", "Create standard milestones for project (1-4)") { options[:action] = 'create_standard' }
end.parse!

if options[:project_id].nil?
  puts "Error: GitLab project ID is required"
  exit 1
end

if options[:token].nil?
  puts "Error: GitLab API token is required (either via --token or GITLAB_PRIVATE_TOKEN env variable)"
  exit 1
end

class GitLabMilestoneManager
  def initialize(options)
    @gitlab_url = options[:gitlab_url].chomp('/')
    @project_id = options[:project_id]
    @token = options[:token]
  end
  
  def list_milestones
    uri = URI.parse("#{@gitlab_url}/api/v4/projects/#{@project_id}/milestones?per_page=100")
    
    response = api_request(uri)
    return [] unless response
    
    milestones = JSON.parse(response.body)
    
    puts "=== GitLab Milestones ==="
    puts "ID | Title | Due Date | State"
    puts "---|-------|----------|------"
    
    milestones.each do |milestone|
      puts "#{milestone['id']} | #{milestone['title']} | #{milestone['due_date'] || 'N/A'} | #{milestone['state']}"
    end
    
    puts "\nTo set in your environment:"
    milestones.each do |milestone|
      # Extract digit from title if available, otherwise use full title
      milestone_key = milestone['title'].match(/\d+/).to_s
      milestone_key = milestone['title'].gsub(/\s+/, '_') if milestone_key.empty?
      
      puts "export GITLAB_MILESTONE_ID_#{milestone_key}=\"#{milestone['id']}\""
    end
    
    milestones
  end
  
  def create_milestone(title, description = nil, due_date = nil)
    uri = URI.parse("#{@gitlab_url}/api/v4/projects/#{@project_id}/milestones")
    
    params = { title: title }
    params[:description] = description if description
    params[:due_date] = due_date if due_date
    
    response = api_request(uri, :post, params)
    return nil unless response
    
    milestone = JSON.parse(response.body)
    puts "Created milestone '#{title}' with ID #{milestone['id']}"
    milestone
  end
  
  def create_standard_milestones
    milestones = []
    today = Date.today
    
    # Create 4 standard milestones, each 2 weeks apart
    (1..4).each do |i|
      title = "Milestone #{i}"
      description = "Project milestone #{i}"
      due_date = (today + (i * 14)).to_s  # Each milestone 2 weeks after the previous
      
      milestone = create_milestone(title, description, due_date)
      milestones << milestone if milestone
    end
    
    milestones
  end
  
  def export_milestones(export_file)
    milestones = list_milestones
    return false if milestones.empty?
    
    milestone_map = {}
    milestones.each do |milestone|
      # Extract digit from title if available, otherwise use full title
      milestone_key = milestone['title'].match(/\d+/).to_s
      milestone_key = milestone['title'].gsub(/\s+/, '_') if milestone_key.empty?
      
      milestone_map[milestone_key] = milestone['id']
    end
    
    # Write to export file
    File.write(export_file, JSON.pretty_generate(milestone_map))
    puts "Exported milestone IDs to #{export_file}"
    
    # Generate shell script for environment variables
    env_script = "#{File.dirname(export_file)}/gitlab_milestones.sh"
    File.open(env_script, 'w') do |f|
      f.puts "# GitLab milestone environment variables"
      f.puts "# Generated on #{Time.now}"
      f.puts
      
      milestone_map.each do |key, value|
        f.puts "export GITLAB_MILESTONE_ID_#{key}=\"#{value}\""
      end
    end
    
    FileUtils.chmod(0755, env_script)
    puts "Created environment script at #{env_script}"
    puts "To load these variables: source #{env_script}"
    
    true
  end
  
  private
  
  def api_request(uri, method = :get, params = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    if method == :get
      request = Net::HTTP::Get.new(uri.request_uri)
    else
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request.body = params.to_json if params
    end
    
    request['PRIVATE-TOKEN'] = @token
    
    begin
      response = http.request(request)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        return response
      else
        puts "API Error: #{response.code} #{response.message}"
        puts "Response body: #{response.body}"
        return nil
      end
    rescue => e
      puts "API Exception: #{e.message}"
      return nil
    end
  end
end

# Execute requested action
manager = GitLabMilestoneManager.new(options)

case options[:action]
when 'list'
  manager.list_milestones
when 'create'
  manager.create_milestone(options[:title], options[:description], options[:due_date])
when 'export'
  manager.export_milestones(options[:export_file])
when 'create_standard'
  manager.create_standard_milestones
end
