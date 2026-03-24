# Hecks::Connections::HttpConnection
#
# Wraps the HTTP REST server as a listens_to connection.
# Starts a WEBrick server that routes requests to domain commands and queries.
#
#   listens_to :http, port: 3000
#
module Hecks
  module Connections
    class HttpConnection
      def initialize(domain, runtime, port: 9292)
        @server = HTTP::DomainServer.new(domain, port: port)
      end

      def start
        @server.run
      end
    end
  end
end
