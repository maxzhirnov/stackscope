class MetricSample < ApplicationRecord
  belongs_to :server

  validates :collected_at, presence: true
end
