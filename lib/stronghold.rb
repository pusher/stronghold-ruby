require 'excon'
require 'json'

module Stronghold
  class Path
    def self.valid(path)
      raise "path should start with a forward slash" unless path[0] == ?/ || path.empty?
      raise "path should not end with a forward slash" if path[-1] == ?/ && path != ?/
    end

    def self.cleanup(path)
      File.expand_path(path, '/').gsub(/\/+/, '/')
    end
  end

  module WithETag
    attr_accessor :etag

    def self.wrap(obj, response)
      obj.extend(self)
      obj.etag = response.headers['ETag']
      obj
    end
  end

  class Tree
    attr_reader :version

    def initialize(client, version)
      @client = client
      @version = version
    end

    ##
    # List the paths that stronghold knows about
    def paths
      resp = @client.connection.get(
        path: "/#{version}/tree/paths",
        expects: 200,
        idempotent: true
      )
      JSON.parse(resp.body)
    end

    ##
    # Extracts the set variables from a particular path level.
    # This means variables set at that level, and none others
    # Generally this is not what you want, unless you are
    # writing an editor
    def peculiar(path)
      Stronghold::Path.valid(path)
      resp = @client.connection.get(
        path: "/#{version}/tree/peculiar#{path}",
        expects: 200,
        idempotent: true
      )
      JSON.parse(resp.body)
    end

    ##
    # Extracts the set variables for a path. This means variables
    # from this level of the path and all previous levels
    # superimposed in order of specialization (lower overrides higher)
    def materialized(path)
      Stronghold::Path.valid(path)
      resp = @client.connection.get(
        path: "/#{version}/tree/materialized#{path}",
        expects: 200,
        idempotent: true
      )
      WithETag.wrap(JSON.parse(resp.body), resp)
    end

    ##
    # Blocks until the materialized JSON for a particular path changes
    def next_materialized(path)
      Stronghold::Path.valid(path)
      resp = @client.connection.get(
        path: "/#{version}/next/tree/materialized#{path}",
        expects: 200,
        idempotent: true
      )
      result = JSON.parse(resp.body)
      {
        data: result["data"],
        version: Version.new(@client, result["revision"])
      }
    end
  end

  class ChangeSet
    def initialize(changes)
      @changes = changes
    end
  end

  class Update
    def initialize(options)
      @options = options
    end

    def author
      @options[:author]
    end

    def timestamp
      @options[:timestamp]
    end

    def comment
      @options[:comment]
    end

    def changeset
      @options[:changes]
    end
  end

  class Version
    attr_reader :version

    def initialize(client, version)
      @client = client
      @version = version
    end

    ##
    # Get the tree of data represented by this version
    def tree
      @tree ||= Tree.new(@client, @version)
    end

    ##
    # Get update data for a past change
    def change
      @change ||= begin
        response = @client.connection.get(
          path: "/#{version}/change",
          expects: 200,
          idempotent: true
        )
        options = JSON.parse(response.body)
        Update.new(
          author: options["author"],
          comment: options["comment"],
          timestamp: options["timestamp"],
          previous: Version.new(@client, options["previous"]),
          changes: ChangeSet.new(options["changes"])
        )
      end
    end

    ##
    # Update or create a new path
    def update(options)
      path, data, author, comment = options.values_at(:path, :data, :author, :comment)
      if [data, author, comment].compact.length != 3
        raise "No null arguments allowed in options: #{options}"
      end
      Stronghold::Path.valid(path)
      resp = Stronghold::Client.wrap("Could not update stronghold") {
        @client.connection.post(
          path: "/#{version}/update#{path}",
          body: JSON.generate(data: data, author: author, comment: comment),
          expects: 200,
          idempotent: true
        )
      }
      Version.new(@client, resp.body)
    end
  end

  class Versions
    def initialize(client)
      @client = client
    end

    def at(ts)
      raise "expected a time" unless ts.kind_of?(Time)
      Version.new(@client, @client.connection.get(
        path: '/versions',
        query: {at: ts.to_i},
        expects: 200,
        idempotent: true
      ).body)
    end

    def before(version, n)
      raise "expected a Version" unless version.kind_of?(Version)
      JSON.parse(@client.connection.get(
        path: '/versions',
        query: {last: version.version, size: n},
        expects: 200,
        idempotent: true
      ).body).map { |x|
        Version.new(@client, x['revision'])
      }
    end
  end

  class Error < StandardError;  end
  class ConnectionError < Error
    attr_reader :child_error
    def initialize(child_error, error_data)
      if child_error.nil?
        super(error_data)
      else
        super("#{error_data}: #{child_error.message} (#{child_error.class})")
        set_backtrace(child_error.backtrace)
        @child_error = child_error
      end
    end
  end

  class Client
    def self.wrap(error = nil, retries = 0, &block)
      done_retries = 0
      ex = nil
      while done_retries <= retries
        begin
          resp = block.call()
          return resp
        rescue Excon::Errors::Error => e
          ex = e
          done_retries += 1
        end
      end
      raise Stronghold::ConnectionError.new(ex, error)
    end

    attr_reader :connection

    ##
    # Connect to stronghold
    def initialize(uri = "http://127.0.0.1:5040")
      @connection = Excon.new(uri, connect_timeout: 5)
      unless Stronghold::Client.wrap("Could not connect to #{uri}", 4) { @connection.get.body } == "Stronghold says hi"
        raise Stronghold::ConnectionError.new(nil, "#{uri} is not stronghold")
      end
    end

    ##
    # Get the latest version, generally what you want
    def head
      Version.new(self, @connection.get(
        path: '/head',
        expects: 200,
        idempotent: true
      ).body)
    end

    def versions
      @versions ||= Versions.new(self)
    end
  end
end
