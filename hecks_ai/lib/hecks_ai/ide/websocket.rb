# Hecks::AI::IDE::WebSocket
#
# Minimal WebSocket server implementation over a raw TCPServer.
# Handles the HTTP upgrade handshake and frame encode/decode for
# bidirectional terminal streaming. No gem dependencies.
#
#   server = TCPServer.new('127.0.0.1', 3002)
#   ws = WebSocket.accept(server)  # blocks until a client connects
#   ws.write("hello")
#   data = ws.read                 # => "hello back"
#
require "socket"
require "digest/sha1"
require "base64"

module Hecks
  module AI
    module IDE
      class WebSocket
        MAGIC = "258EAFA5-E914-47DA-95CA-5AB5DC65C3A7"

        def initialize(socket)
          @socket = socket
          @write_mutex = Mutex.new
        end

        def self.accept(tcp_server)
          client = tcp_server.accept
          request = ""
          while (line = client.gets) && line.strip != ""
            request << line
          end

          key = request[/Sec-WebSocket-Key: (.+)\r\n/, 1]&.strip
          unless key
            client.close
            return nil
          end

          accept_key = Base64.strict_encode64(
            Digest::SHA1.digest(key + MAGIC)
          )

          client.write(
            "HTTP/1.1 101 Switching Protocols\r\n" \
            "Upgrade: websocket\r\n" \
            "Connection: Upgrade\r\n" \
            "Sec-WebSocket-Accept: #{accept_key}\r\n" \
            "\r\n"
          )

          new(client)
        end

        def read
          first_byte = @socket.getbyte
          return nil unless first_byte

          opcode = first_byte & 0x0f
          return :close if opcode == 8
          return :ping  if opcode == 9

          second_byte = @socket.getbyte
          masked = (second_byte & 0x80) != 0
          length = second_byte & 0x7f

          length = @socket.read(2).unpack1("n")  if length == 126
          length = @socket.read(8).unpack1("Q>") if length == 127

          mask_key = masked ? @socket.read(4).bytes : nil
          payload = length > 0 ? @socket.read(length) : ""

          if masked && payload
            payload = payload.bytes.each_with_index.map { |b, i|
              b ^ mask_key[i % 4]
            }.pack("C*")
          end

          payload.force_encoding("UTF-8")
        rescue EOFError, Errno::ECONNRESET, IOError
          nil
        end

        def write(data)
          @write_mutex.synchronize do
            bytes = data.bytes
            frame = [0x81]

            if bytes.length < 126
              frame << bytes.length
            elsif bytes.length < 65_536
              frame << 126
              frame += [bytes.length].pack("n").bytes
            else
              frame << 127
              frame += [bytes.length].pack("Q>").bytes
            end

            @socket.write(frame.pack("C*") + bytes.pack("C*"))
            @socket.flush
          end
        rescue Errno::EPIPE, Errno::ECONNRESET, IOError
          nil
        end

        def close
          @socket.close rescue nil
        end

        def closed?
          @socket.closed?
        end
      end
    end
  end
end
