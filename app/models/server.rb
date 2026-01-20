require "json"
require "uri"

class Server < ApplicationRecord
  has_many :metric_samples, dependent: :destroy

  validates :name, presence: true
  validates :host, presence: true
  validates :port, numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }, allow_nil: true
  validates :agent_url, allow_blank: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :ping_interval_seconds,
            numericality: { only_integer: true, greater_than: 5, less_than_or_equal_to: 3600 },
            allow_nil: true
  validates :ping_latency_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def display_host
    port.present? ? "#{host}:#{port}" : host
  end

  def display_host_no_port
    host.to_s
  end

  def ping_interval
    ping_interval_seconds.presence || 60
  end

  def extended_metrics_payload
    return nil if extended_metrics_json.blank?

    JSON.parse(extended_metrics_json)
  rescue JSON::ParserError
    nil
  end
end
