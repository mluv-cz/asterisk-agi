require_relative '../../test_helper'

class TestServer < Minitest::Test
  def setup
    @server = Asterisk::Agi::Server.new
  end

  def test_no_handler
    err = assert_raises do
      @server.serve sck
    end
    assert err.message.include? "No handlers defined"
  end

  def test_block_handler
    @server.handle "dialplan" do |conn|
      assert_equal "dialplan", conn.network_script
      assert_equal "SIP", conn.type
      assert_equal "cisco-spa", conn.channel.name
      assert_equal "1", conn.accountcode
    end
    @server.serve sck

  end

  def sck
    StringIO.new <<-AGI_OUTPUT
agi_network_script: dialplan
agi_type: SIP
agi_channel: SIP/cisco-spa-00000001
agi_accountcode: 1

AGI_OUTPUT
  end
end
