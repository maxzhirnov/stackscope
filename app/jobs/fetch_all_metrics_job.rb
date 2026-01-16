class FetchAllMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Server.where.not(agent_url: [nil, ""]).find_each do |server|
      FetchMetricsJob.perform_later(server.id)
    end
  end
end
