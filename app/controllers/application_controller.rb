class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_time_zone
  before_action :ensure_admin_credentials
  before_action :require_login

  private

  def set_time_zone
    zone = cookies[:timezone]
    return if zone.blank?

    if ActiveSupport::TimeZone[zone]
      Time.zone = zone
    else
      Time.zone = TZInfo::Timezone.get(zone)
    end
  rescue TZInfo::InvalidTimezoneIdentifier
    nil
  end

  def ensure_admin_credentials
    return if AdminCredential.exists?

    username = ENV["STACKSCOPE_ADMIN_USER"]
    password = ENV["STACKSCOPE_ADMIN_PASSWORD"]
    return if username.blank? || password.blank?

    AdminCredential.create!(username: username, password: password)
  end

  def require_login
    return if current_admin

    if AdminCredential.exists?
      redirect_to new_session_path, alert: "Please sign in."
    else
      redirect_to new_setup_path
    end
  end

  helper_method :current_admin

  def current_admin
    return @current_admin if defined?(@current_admin)

    @current_admin = AdminCredential.find_by(id: session[:admin_id])
  end
end
