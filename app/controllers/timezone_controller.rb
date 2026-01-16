class TimezoneController < ApplicationController
  def update
    zone = params[:timezone]
    if zone.present? && ActiveSupport::TimeZone[zone]
      cookies[:timezone] = { value: zone, expires: 1.year.from_now }
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
