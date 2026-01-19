class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.value = value
    record.save!
  end

  def self.enabled?(key, default: true)
    raw = get(key, default.to_s)
    raw.to_s == "true"
  end
end
