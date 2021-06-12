require "gserver"
require_relative "connection.rb"

module Asterisk
  module Agi

    class Server < GServer
      def initialize(args = {})
        @handlers = {}
        host = args.fetch :host, "0.0.0.0"
        port = args.fetch :port, 4573
        max_connections = args.fetch :max_connections, 100
        @logger = args.fetch :logger, nil
        super port, host, max_connections, logger, true, true
      end

      def add_handler(network_script, handler = nil, &block)
        @handlers[network_script.to_s] = handler || block
      end
      alias :handle :add_handler

      def serve(io)
        conn = Asterisk::Agi::Connection.new io
        unless handler = @handlers[conn[:network_script]]
          raise "No handlers defined. Requested script name: \"#{conn[:network_script]}\"."
        end
        unless handler.respond_to? :call
          raise ArgumentError.new "Handlers must respond to \"call\", receive one argument."
        end
        handler.(conn)
      end
    
      def starting
        logger.info "#{self.class}: Server #{host}:#{port} starting..."
      end
    
      def stopping
        logger.info "#{self.class}: Server #{host}:#{port} stoped."
      end
    
      def connecting(client)
        logger.info "#{self.class}: #{host}:#{port} client:#{client.peeraddr[1]} #{client.peeraddr[2]}<#{client.peeraddr[3]}> connected."
      end
    
      def disconnecting(port)
        logger.info "#{self.class}: #{host}:#{port} client:#{port} disconnected."
      end

      def error(detail)
        logger.error detail.backtrace.reverse.join("\n")
        logger.error "#{self.class}: #{detail}"
        raise detail
      end

      def logger
        @logger ||= Class.new { def info; end }.new
      end

    end
  end
end
