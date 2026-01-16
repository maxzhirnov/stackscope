class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_time_zone

  private

  def set_time_zone
    zone = cookies[:timezone]
    Time.zone = zone if zone.present? && ActiveSupport::TimeZone[zone]
  end
end
