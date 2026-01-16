require "socket"

class PingServerJob < ApplicationJob
  queue_as :default

  DEFAULT_PORT = 80
  CONNECT_TIMEOUT = 2

  def perform(server_id)
    server = Server.find_by(id: server_id)
    return if server.blank?

    online, latency_ms = tcp_check(server.host, server.port || DEFAULT_PORT)
    server.update(
      status: online ? "online" : "offline",
      last_ping_at: Time.current,
      ping_latency_ms: online ? latency_ms : nil
    )
  end

  private

  def tcp_check(host, port)
    return false if host.blank?

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Socket.tcp(host, port, connect_timeout: CONNECT_TIMEOUT) { |socket| socket.close }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    [true, (elapsed * 1000).round]
  rescue StandardError
    [false, nil]
  end
end
