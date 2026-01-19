class FetchAllMetricsJob < ApplicationJob
  queue_as :default

  def perform
    return unless AppSetting.enabled?("servers_checks_enabled", default: true)

    Server.where.not(agent_url: [nil, ""]).find_each do |server|
      FetchMetricsJob.perform_later(server.id)
    end
  end
end
