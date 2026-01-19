require "net/http"
require "uri"

class CheckShortcutJob < ApplicationJob
  queue_as :default

  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 3

  def perform(shortcut_id)
    shortcut = Shortcut.find_by(id: shortcut_id)
    return if shortcut.blank? || shortcut.url.blank?

    response = fetch(shortcut.url)
    status_code = response&.code.to_i
    status = response && status_code.between?(200, 399) ? "up" : "down"

    shortcut.update(
      last_status: status,
      last_status_code: status_code.zero? ? nil : status_code,
      last_checked_at: Time.current
    )
  rescue StandardError
    shortcut&.update(last_status: "down", last_status_code: nil, last_checked_at: Time.current)
  end

  private

  def fetch(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Head.new(uri)
    response = http.request(request)
    return response unless response.code.to_i == 405

    http.request(Net::HTTP::Get.new(uri))
  end
end
