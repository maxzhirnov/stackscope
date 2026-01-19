require "json"

class MetricSample < ApplicationRecord
  belongs_to :server

  validates :collected_at, presence: true

  def fs_usage
    return [] if fs_usage_json.blank?

    JSON.parse(fs_usage_json)
  rescue JSON::ParserError
    []
  end
end
