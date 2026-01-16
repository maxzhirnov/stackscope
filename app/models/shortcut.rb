class Shortcut < ApplicationRecord
  has_one_attached :icon_image

  validates :name, presence: true
  validates :url, presence: true
end
