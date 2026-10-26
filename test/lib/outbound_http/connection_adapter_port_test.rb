# frozen_string_literal: true

require "test_helper"

class OutboundHttpConnectionAdapterPortTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "connection setup pins the checked public address while preserving the TLS hostname" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: true)
    Addrinfo.stub(:getaddrinfo, [Addrinfo.tcp("93.184.216.34", 443)]) do
      connection = adapter.net_http_connection(url: URI("https://rp.example/closures"), request: { proxy: nil })

      assert_equal "rp.example", connection.address
      assert_equal "93.184.216.34", connection.ipaddr
      assert_equal 443, connection.port
    end
  end

  test "any private answer in a mixed DNS result rejects the endpoint before connection setup" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: true)

    Addrinfo.stub(:getaddrinfo, [Addrinfo.tcp("93.184.216.34", 443), Addrinfo.tcp("127.0.0.1", 443)]) do
      assert_raises(OutboundHttp::Connection::InsecureEndpointError) do
        adapter.net_http_connection(url: URI("https://rp.example/closures"), request: { proxy: nil })
      end
    end
  end

  test "cloud metadata and IPv6 non-global answers are rejected" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: true)
    ["169.254.169.254", "fd00::1", "2001:db8::1", "2002:a00:1::1"].each do |address|
      Addrinfo.stub(:getaddrinfo, [Addrinfo.tcp(address, 443)]) do
        assert_raises(OutboundHttp::Connection::InsecureEndpointError, address) do
          adapter.net_http_connection(url: URI("https://rp.example/closures"), request: { proxy: nil })
        end
      end
    end
  end

  test "DNS failure remains a transport failure" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: true)

    Addrinfo.stub(:getaddrinfo, ->(*) { raise SocketError, "temporary DNS failure" }) do
      assert_raises(Faraday::ConnectionFailed) do
        adapter.net_http_connection(url: URI("https://rp.example/closures"), request: { proxy: nil })
      end
    end
  end

  test "registered public endpoint cannot route through a proxy" do
    adapter = OutboundHttp::ConnectionAdapterPort.new(->(_env) { }, require_public_address: true)

    assert_raises(OutboundHttp::Connection::InsecureEndpointError) do
      adapter.net_http_connection(url: URI("https://rp.example/closures"), request: { proxy: "http://proxy.example" })
    end
  end
end
