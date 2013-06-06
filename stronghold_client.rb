require 'excon'
require 'json'

module Stronghold
  class Tree
    attr_reader :version

    def initialize(client, version)
      @client = client
      @version = version
    end

    def paths
      resp = @client.connection.get(
        path: "/#{version}/tree/paths",
        expects: 200
      )
      JSON.parse(resp.body)
    end

    def peculiar(path)
      raise "path should start with a forward slash" unless path[0] == '/'
      resp = @client.connection.get(
        path: "/#{version}/tree/peculiar#{path}",
        expects: 200
      )
      JSON.parse(resp.body)
    end

    def materialized(path)
      raise "path should start with a forward slash" unless path[0] == '/'
      resp = @client.connection.get(
        path: "/#{version}/tree/materialized#{path}",
        expects: 200
      )
      JSON.parse(resp.body)
    end

    def next_materialized(path)
      raise "path should start with a forward slash" unless path[0] == '/'
      resp = @client.connection.get(
        path: "/#{version}/next/tree/materialized#{path}",
        expects: 200
      )
      result = JSON.parse(resp.body)
      {
        data: result,
        version: nil
      }
    end
  end

  class Change
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

    def path
      @options[:path]
    end

    def data
      @options[:data]
    end
  end

  class Version
    attr_reader :version

    def initialize(client, version)
      @client = client
      @version = version
    end

    def tree
      @tree ||= Tree.new(@client, @version)
    end

    def change
      @change ||= begin
        response = @client.connection.get(
          path: "/#{version}/change",
          expects: 200
        )
        options = JSON.parse(response.body)
        Change.new(
          author: options["author"],
          comment: options["comment"],
          timestamp: options["timestamp"],
          path: options["path"],
          data: options["data"],
          previous: Version.new(@client, options["previous"])
        )
      end
    end

    def update(options)
      path, data, author, comment = options.values_at(:path, :data, :author, :comment)
      raise "path should start with a forward slash" unless path[0] == '/'
      resp = @client.connection.post(
        path: "/#{version}/update#{path}",
        body: JSON.generate(data: data, author: author, comment: comment),
        expects: 200
      )
      Version.new(@client, resp.body)
    end
  end

  class Versions
    def initialize(client)
      @client = client
    end

    def at(ts)
    end

    def before(version, n)
    end
  end

  class Client
    attr_reader :connection

    def initialize(uri)
      @connection = Excon.new(uri)
    end

    def head
      Version.new(self, @connection.get(path: '/head', expects: 200).body)
    end

    def versions
      @versions ||= StrongholdVersions.new(self)
    end
  end
end
