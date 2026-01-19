require "json"
require "net/http"
require "time"
require "uri"

class FetchMetricsJob < ApplicationJob
  queue_as :default

  REQUEST_TIMEOUT = 4

  def perform(server_id)
    server = Server.find_by(id: server_id)
    return if server.blank? || server.agent_url.blank?

    payload = fetch_metrics(server)
    return unless payload

    server.metric_samples.create!(
      cpu_usage: payload[:cpu_usage],
      memory_usage: payload[:memory_usage],
      disk_usage: payload[:disk_usage],
      load_avg: payload[:load_avg],
      agent_version: payload[:agent_version],
      uptime_seconds: payload[:uptime_seconds],
      swap_usage: payload[:swap_usage],
      disk_read_bps: payload[:disk_read_bps],
      disk_write_bps: payload[:disk_write_bps],
      net_rx_bps: payload[:net_rx_bps],
      net_tx_bps: payload[:net_tx_bps],
      fs_usage_json: payload[:fs_usage_json],
      collected_at: payload[:collected_at] || Time.current
    )
    server.update(last_metrics_at: payload[:collected_at] || Time.current)
  end

  private

  def fetch_metrics(server)
    uri = URI.parse(server.agent_url)
    request = Net::HTTP::Get.new(uri)
    if server.agent_token.present?
      request["X-Stackscope-Token"] = server.agent_token
    end

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: REQUEST_TIMEOUT,
      read_timeout: REQUEST_TIMEOUT
    ) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(response.body)
    {
      cpu_usage: parsed["cpu_usage"],
      memory_usage: parsed["memory_usage"],
      disk_usage: parsed["disk_usage"],
      load_avg: parsed["load_avg"],
      uptime_seconds: parsed["uptime_seconds"],
      swap_usage: parsed["swap_usage"],
      disk_read_bps: parsed["disk_read_bps"],
      disk_write_bps: parsed["disk_write_bps"],
      net_rx_bps: parsed["net_rx_bps"],
      net_tx_bps: parsed["net_tx_bps"],
      fs_usage_json: parsed["fs_usage"] ? JSON.dump(parsed["fs_usage"]) : nil,
      agent_version: parsed["agent_version"],
      collected_at: parse_time(parsed["collected_at"])
    }
  rescue StandardError => e
    Rails.logger.warn("Metrics fetch failed for server #{server.id}: #{e.class} #{e.message}")
    nil
  end

  def parse_time(value)
    return nil if value.blank?

    Time.iso8601(value)
  rescue ArgumentError
    nil
  end
end
