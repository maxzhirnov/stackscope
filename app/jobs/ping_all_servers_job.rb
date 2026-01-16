require "socket"

class PingAllServersJob < ApplicationJob
  queue_as :default

  def perform
    now = Time.current
    Server.find_each do |server|
      next unless due_for_ping?(server, now)

      PingServerJob.perform_later(server.id)
    end
  end

  private

  def due_for_ping?(server, now)
    return true if server.last_ping_at.blank?

    now - server.last_ping_at >= server.ping_interval
  end
end
