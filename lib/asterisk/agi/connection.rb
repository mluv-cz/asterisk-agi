require_relative "channel.rb"

module Asterisk
  module Agi
    class InvalidCommand < StandardError; end
    class InvalidResponse < StandardError; end
    class Hangup < StandardError; end

    # represents a connection with Asterisk Gateway Interface (AGI)
    # implemented using asterisk/res/res_agi.c as reference
    class Connection
      attr_reader :conn_params

      STATUS_CODES = {
        200 => "OK",
        510 => "Invalid or unknown command",
        511 => "Command Not Permitted on a dead channel",
        520 => "Invalid command syntax."
      }
      DEBUG = false unless defined? DEBUG

      def initialize(sck)
        @sck = sck
        @conn_params = {}
        while l = sck.gets
          break if l.nil? || l.length <= 1
          k, v = l.strip.split(":", 2)
          k = k[4..-1] if k && k.start_with?("agi_")
          v.strip! if v
          v = nil if v && v.length == 0
          @conn_params[k.to_sym] = v if k
          puts ">> #{k}> #{v}" if DEBUG
        end
      end

      def answer
        write "ANSWER"
        read
      end

      def hangup
        write "HANGUP"
        res = read
        @sck.close
        res
      end

      # waittime: time to wait if called party picks up before giving up
      # time: hangup the call after this number of seconds
      def dial(number, waittime = nil, time = nil, params = {})
        # g: When the called party hangs up, continue to execute commands
        # in the current context at the next priority.
        # S(n): Hangup the call n seconds AFTER called party picks up.
        args = "#{number},"
        args << "#{waittime}" if waittime
        args << ","
        args << "g" if params.fetch(:continue_after_hangup, true)
        #args << "L(10000,5000,1000)" # TODO ?
        args << "m" if params.fetch(:musiconhold, false)
        args << "S(#{time})" if time
        args << params[:extra] if params[:extra]
        exec "DIAL", args
      end

      def pickup(extension)
        exec "PICKUP", extension
      end
      alias :pick_up :pickup

      # Originate(tech_data,type,arg1[,arg2[,arg3]])
      # - tech_data - Channel technology and data for creating the outbound channel. For example, SIP/1234.
      # - type - This should be 'app' or 'exten', depending on whether the outbound channel should be connected to an application or extension.
      # - arg1 - If the type is 'app', then this is the application name. If the type is 'exten', then this is the context that the channel will be sent to.
      # - arg2 - If the type is 'app', then this is the data passed as arguments to the application. If the type is 'exten', then this is the extension that the channel will be sent to.
      # - arg3 - If the type is 'exten', then this is the priority that the channel is sent to. If the type is 'app', then this parameter is ignored.
      def originate(number, type, *params)
        unless params.length >= 1
          raise ArgumentError.new "Must specify the app name or context"
        end
        unless [ "app", "exten" ].include? type
          raise ArgumentError.new "Type must be \"app\" or \"exten\""
        end
        args = "#{number},#{type},"
        args << params.first
        [*params].each do |p|
          args << ",#{p}"
        end
        exec "ORIGINATE", args
      end

      def playback(file, args = nil)
        cmd = "PLAYBACK #{file}"
        cmd << ",#{args}" if args
        exec cmd
      end

      def get_data(file, timeout = nil, maxdigits = nil)
        cmd = "GET DATA #{file}"
        cmd << " #{timeout}" if timeout
        cmd << " #{maxdigits}" if timeout and maxdigits
        write cmd
        read
      end

      def wait(seconds)
        exec "WAIT", seconds
      end

      def wait_for_digit(timeout = -1)
        cmd = "WAIT FOR DIGIT"
        cmd << " #{timeout}"
        write cmd
        read
      end

      def ringing
        exec "RINGING"
      end
      alias :ring :ringing

      def musiconhold(cls = nil)
        cmd = "MUSICONHOLD"
        cmd << " #{cls}" if cls
        exec cmd
      end

      def setmusiconhold(cls)
        set_variable "CHANNEL(musicclass)", cls
        read
      end
      alias :set_music_on_hold :setmusiconhold

      def set_sip_message(body)
        set "MESSAGE(body)", "\"#{body}\""
      end

      def send_sip_message(to, from = nil)
        args = "sip:#{to}"
        args << ",<sip:#{from}>" if from
        exec "MessageSend", args
      end

      def exec(app, args = nil)
        cmd = "EXEC #{app}"
        cmd << " #{args}" if args
        write cmd
        read
      end

      def get_variable(var)
        write "GET VARIABLE #{var}"
        read
      end
      alias :get_var :get_variable
      alias :get :get_variable

      def set_variable(var, val)
        val = "\"\"" if val.nil? || val == ""
        write "SET VARIABLE #{var} #{val}"
        read
      end
      alias :set_var :set_variable
      alias :set :set_variable

      def [](k)
        conn_params[k.to_sym]
      end

      def channel
        @channel ||= Asterisk::Agi::Channel.new(conn_params[:channel])
      end

      def extension
        self[:extension]
      end
      alias :ext :extension
      alias :extn :extension
      alias :exten :extension

      def local?
        type == "Local"
      end

      # check for conn parameter
      def method_missing(k, *args)
        return self[k] if conn_params.has_key?(k)
        super
      end

      private

      def write(msg)
        @sck.puts msg
        @sck.flush
      end

      # <status_code><space_or_hyphen><space>result=<result>[<space><data>]
      def read
        l = @sck.gets.strip rescue nil
        # TODO HANGUP may be sent after any response (AGISIGHUP channel var.)
        #raise Hangup if l.nil? or l == "HANGUP"

        raise Hangup if l.nil?
        # skip over HANGUP, may be sent as answer to any request
        return read if l == "HANGUP"
 
        code = l[0..2].to_i
        data = l[4..-1]
        raise Hangup if code.nil? || code == 511
        raise InvalidCommand.new "#{STATUS_CODES[510]} #{data}" if code == 510
        if code == 520
          # if code is followed by a hyphen instead of a space, the
          # response will span multiple lines
          if l[3].chr == "-"
            data << "  Proper usage follows:\n"
            while l = @sck.gets.strip
              break if l.start_with?("520")
              data << l 
            end
          else
            data << "  Proper usage not available."
          end
          raise InvalidCommand.new "#{STATUS_CODES[520]} #{data}"
        end
        if code == 200
          res, data = data.strip.split(" ", 2) # ["result=x", "(somethig) else=here and=here"]
          res = res.split("=", 2).last.to_i # get the x from result=x
          # now, there are few cases to handle:
          # we've got only result=x, return the x
          return res if data.nil?
          # if there is only result in parentheses return it
          return data[1..-2] if data && data.start_with?("(") && data.end_with?(")")
          # there's the parenthesis part and something else
          # or just something else, return it in a hash
          h = { result: res}
          parts = data.split(" ")
          # the value in parenthesis
          h[:data] = parts.slice!(0)[1..-2] if data.start_with?("(")
          # the key=value pairs
          parts.each do |p|
            k, v = p.split("=", 2)
            h[k.to_sym] = v
          end
          return h
        end
        raise InvalidResponse.new("Received unknown status code #{code} from AGI, data: \"#{l}\".")
      end

    end
  end
end
