require "uri"

class Shortcut < ApplicationRecord
  has_one_attached :icon_image

  validates :name, presence: true
  validates :url, presence: true
  validates :icon_url, allow_blank: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :check_interval_seconds,
            numericality: { only_integer: true, greater_than: 5, less_than_or_equal_to: 3600 },
            allow_nil: true

  COLOR_PALETTE = %w[#1c7c73 #e08a2e #205072 #b1454a #6b7c3d #4f2d7f].freeze

  def icon_background_color
    seed = name.to_s.bytes.sum + id.to_i
    COLOR_PALETTE[seed % COLOR_PALETTE.length]
  end

  def display_url
    uri = URI.parse(url)
    uri.host.presence || url
  rescue URI::InvalidURIError
    url.to_s
  end

  def check_interval
    check_interval_seconds.presence || 60
  end

  def status_class
    return "neutral" unless monitor_enabled?

    case last_status
    when "up"
      "ok"
    when "down"
      "bad"
    else
      "neutral"
    end
  end
end
