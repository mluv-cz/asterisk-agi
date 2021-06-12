# About

This repository contains the ruby server library for the Asterisk Gateway Interface (AGI).
It listens on specified TCP port for connections from running asterisk server instances.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'asterisk-agi'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install asterisk-agi

and then require it:

```ruby
require 'asterisk/agi/server'
```

## Usage

### Asterisk server configuration

```ini
; extensions.conf
[default]

; catch all dialed numbers
; use port 4573 (default)
; send script name "dialplan"
exten => _[0-9].,1,AGI(agi://127.168.1.2:4573/dialplan)
same  =>         n,Hangup

; specific number, port and script name are optional
exten => 20,1,AGI(agi://192.168.1.2)
same  =>    n,Hangup
```

### Ruby

#### Basic usage

```ruby
# instantiate the server
server = Asterisk::Agi::Server.new(
  host: "0.0.0.0",           # default
  port: 4573,                # default
  max_connections: 100,      # default
  logger: Logger.new(STDOUT) # optional
)

# block called for connections with "dialplan" script name
server.handle "dialplan" do |conn|
  puts "Dialed extension: #{conn.extension}"
  puts "Caller: #{conn.callerid}"

  puts "Connection parameters:"
  conn.conn_params.each do |k, v|
    puts "\t#{k}: #{v}"
  end
end

# handler class which responds to call
class AgiConnectionHandler
  def call(conn)
    # ...
  end
end

server.add_handler "dialplan", AgiConnectionHandler.new

server.start
sleep
```

#### Creating a basic dialplan

```ruby
class BasicDialplanCallHandler
  def call(conn)
    if conn.extension == "20"
      conn.dial "SIP/PhoneA"
    elsif conn.extension == "21"
      conn.dial "SIP/PhoneB"
    else
      conn.playback "extension_not_found"
    end
  end
end

server = Asterisk::Agi::Server.new(
  logger: Logger.new(STDOUT)
)
server.add_handler "dialplan", BasicDialplanCallHandler.new
server.start
sleep
```

## Contributing

1. Fork it ( https://github.com/mluv-cz/asterisk-agi/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
