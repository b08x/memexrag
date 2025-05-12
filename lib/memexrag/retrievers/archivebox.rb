# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module ArchiveBox
  class Error < StandardError; end
  class APIError < Error; end
  class AuthenticationError < APIError; end
  class ResourceNotFoundError < APIError; end

  # Main client class for interacting with ArchiveBox API
  class Client
    attr_reader :base_url

    def initialize(base_url, username = nil, password = nil, api_token: nil)
      @base_url = base_url.chomp('/')
      @username = username
      @password = password
      @api_token = api_token
      @auth_token = nil
    end

    # Authentication methods
    def authenticate
      return @auth_token if @auth_token

      if @api_token
        @auth_token = @api_token
      elsif @username && @password
        response = request(:post, '/api/v1/auth/login/', body: {
          username: @username,
          password: @password
        })
        @auth_token = response['token']
      else
        raise AuthenticationError, 'Must provide either username/password or api_token'
      end
 
      @auth_token
    end

    # Archive management methods
    def add_urls(urls, tag: nil, depth: 0, extractors: nil)
      urls = [urls] unless urls.is_a?(Array)
      params = { urls: urls }
      params[:tag] = tag if tag
      params[:depth] = depth if depth
      params[:extractors] = extractors if extractors

      response = request(:post, '/api/v1/archive/', body: params)
      response['results'].map { |r| ArchiveResult.new(r) }
    end

    def get_archive_results(page = 1, page_size = 100, **filters)
      params = { page: page, page_size: page_size }
      filters.each do |key, value|
        params[key] = value
      end

      response = request(:get, '/api/v1/archive/', params: params)
      {
        results: response['results'].map { |r| ArchiveResult.new(r) },
        count: response['count'],
        next_page: response['next'],
        previous_page: response['previous']
      }
    end

    def get_archive_result(id)
      response = request(:get, "/api/v1/archive/#{id}/")
      ArchiveResult.new(response)
    end

    def delete_archive_result(id)
      request(:delete, "/api/v1/archive/#{id}/")
      true
    end

    # Snapshot methods
    def get_snapshot(id)
      response = request(:get, "/api/v1/snapshots/#{id}/")
      Snapshot.new(response)
    end

    def get_snapshot_content(id, extractor)
      # This returns the actual content or download URL
      request(:get, "/api/v1/archive/#{id}/#{extractor}/")
    end

    # Tag methods
    def get_tags
      response = request(:get, '/api/v1/tags/')
      response['results'].map { |t| Tag.new(t) }
    end

    def create_tag(name)
      response = request(:post, '/api/v1/tags/', body: { name: name })
      Tag.new(response)
    end

    def delete_tag(id)
      request(:delete, "/api/v1/tags/#{id}/")
      true
    end

    # Scheduled archiving
    def schedule_archive(url, interval, tag: nil, depth: 0, extractors: nil)
      params = {
        url: url,
        interval: interval
      }
      params[:tag] = tag if tag
      params[:depth] = depth if depth
      params[:extractors] = extractors if extractors

      response = request(:post, '/api/v1/schedule/', body: params)
      response['id']
    end

    # CLI command execution
    def execute_command(command, args = [])
      params = {
        command: command,
        args: args
      }
      request(:post, '/api/v1/cli/', body: params)
    end

    private

    def request(method, path, params: {}, body: nil, headers: {})
      uri = URI.parse("#{@base_url}#{path}")
      
      # Add query parameters if any
      unless params.empty?
        uri.query = URI.encode_www_form(params)
      end
      
      # Create request object based on method
      request = case method
      when :get
        Net::HTTP::Get.new(uri)
      when :post
        Net::HTTP::Post.new(uri)
      when :put
        Net::HTTP::Put.new(uri)
      when :patch
        Net::HTTP::Patch.new(uri)
      when :delete
        Net::HTTP::Delete.new(uri)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
      
      # Set content type for body
      if body
        request.content_type = 'application/json'
        request.body = body.to_json
      end
      
      # Set authentication header if authenticated, but not for the auth request itself
      unless path == '/api/v1/auth/login/'
        token = authenticate
        if token
          request['Authorization'] = "Token #{token}"
        end
      end
      
      # Add additional headers
      headers.each do |key, value|
        request[key] = value
      end
      
      # Make the request
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
      
      # Handle the response
      case response
      when Net::HTTPSuccess
        return {} if response.body.nil? || response.body.empty?
        JSON.parse(response.body)
      when Net::HTTPUnauthorized, Net::HTTPForbidden
        body = JSON.parse(response.body) rescue { error: response.message }
        error_message = body["error"] || response.message
        raise AuthenticationError, "Authentication failed: #{error_message}"
      when Net::HTTPNotFound
        body = JSON.parse(response.body) rescue { error: response.message }
        error_message = body["error"] || response.message
        raise ResourceNotFoundError, "Resource not found: #{error_message}"
      else
        body = JSON.parse(response.body) rescue { error: response.message }
        error_message = body["error"] || response.message
        
        raise APIError, "HTTP Error: #{response.code} - #{error_message}"
      end
    end
  end

  # Helper classes for API resources
  class ArchiveResult
    attr_reader :id, :url, :title, :timestamp, :tags, :snapshots
    
    def initialize(data)
      @id = data['id']
      @url = data['url']
      @title = data['title']
      @timestamp = data['timestamp']
      @tags = data['tags']
      @snapshots = data['snapshots']&.map { |s| Snapshot.new(s) } if data['snapshots']
    end

    def to_h
      {
        id: @id,
        url: @url,
        title: @title,
        timestamp: @timestamp,
        tags: @tags,
        snapshots: @snapshots&.map(&:to_h)
      }
    end
  end

  class Snapshot
    attr_reader :id, :extractor, :output, :timestamp
    
    def initialize(data)
      @id = data['id']
      @extractor = data['extractor']
      @output = data['output']
      @timestamp = data['timestamp']
    end

    def to_h
      {
        id: @id,
        extractor: @extractor,
        output: @output,
        timestamp: @timestamp
      }
    end
  end

  class Tag
    attr_reader :id, :name
    
    def initialize(data)
      @id = data['id']
      @name = data['name']
    end

    def to_h
      {
        id: @id,
        name: @name
      }
    end
  end
end