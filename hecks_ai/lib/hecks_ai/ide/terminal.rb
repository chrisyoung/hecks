# Hecks::AI::IDE::Terminal
#
# Wraps a PTY-spawned process for bidirectional I/O. Spawns the given
# command in a pseudo-terminal and provides read/write/resize methods
# for bridging to a WebSocket.
#
#   term = Terminal.new("claude --dangerously-skip-permissions")
#   term.write("hello\n")
#   output = term.read  # => ANSI-encoded terminal output
#   term.resize(120, 40)
#
require "pty"

module Hecks
  module AI
    module IDE
      class Terminal
        attr_reader :pid

        def initialize(command, cols: 120, rows: 40)
          @master, _slave, @pid = PTY.spawn(
            { "TERM" => "xterm-256color" }, command
          )
          @master.winsize = [rows, cols]
        end

        def read
          return nil unless IO.select([@master], nil, nil, 0.05)
          data = @master.read_nonblock(16_384)
          data.force_encoding("UTF-8")
          data.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
        rescue IO::WaitReadable
          nil
        rescue EOFError, Errno::EIO
          nil
        end

        def write(data)
          @master.write(data)
        end

        def resize(cols, rows)
          @master.winsize = [rows, cols]
          Process.kill(:WINCH, @pid) rescue nil
        end

        def alive?
          Process.waitpid(@pid, Process::WNOHANG).nil?
        rescue Errno::ECHILD, PTY::ChildExited
          false
        end

        def close
          @master.close rescue nil
          Process.kill(:TERM, @pid) rescue nil
        end
      end
    end
  end
end
