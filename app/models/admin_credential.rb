class AdminCredential < ApplicationRecord
  has_secure_password

  before_validation :normalize_username

  validates :username, presence: true, uniqueness: { case_sensitive: false }

  private

  def normalize_username
    self.username = username.to_s.strip
  end
end
