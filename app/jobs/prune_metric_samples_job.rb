class PruneMetricSamplesJob < ApplicationJob
  queue_as :default

  RETENTION_DAYS = 7

  def perform
    MetricSample.where("collected_at < ?", RETENTION_DAYS.days.ago).delete_all
  end
end
