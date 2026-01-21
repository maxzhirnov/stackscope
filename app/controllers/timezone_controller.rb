class TimezoneController < ApplicationController
  skip_before_action :require_login
  skip_before_action :ensure_admin_credentials
  skip_before_action :verify_authenticity_token, only: :update

  def update
    zone = normalize_time_zone(params[:timezone])
    if zone
      cookies[:timezone] = { value: zone, expires: 1.year.from_now }
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def normalize_time_zone(zone)
    return if zone.blank?
    return zone if ActiveSupport::TimeZone[zone]

    TZInfo::Timezone.get(zone).identifier
  rescue TZInfo::InvalidTimezoneIdentifier
    nil
  end
end
