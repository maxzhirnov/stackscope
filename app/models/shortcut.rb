require "uri"

class Shortcut < ApplicationRecord
  has_one_attached :icon_image

  validates :name, presence: true
  validates :url, presence: true
  validates :icon_url, allow_blank: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])

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
end
