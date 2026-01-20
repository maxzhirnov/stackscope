class MonitoringController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[
    toggle_servers
    toggle_shortcuts
    run_servers
    run_shortcuts
  ]

  def toggle_servers
    toggle("servers_checks_enabled")
    redirect_to root_path
  end

  def toggle_shortcuts
    toggle("shortcuts_checks_enabled")
    redirect_to root_path
  end

  def run_servers
    Server.find_each do |server|
      PingServerJob.perform_later(server.id)
      FetchMetricsJob.perform_later(server.id)
    end
    redirect_to root_path, notice: "Server checks triggered."
  end

  def run_shortcuts
    Shortcut.where(monitor_enabled: true).find_each do |shortcut|
      CheckShortcutJob.perform_later(shortcut.id)
    end
    redirect_to root_path, notice: "Shortcut checks triggered."
  end

  private

  def toggle(key)
    current = AppSetting.enabled?(key, default: true)
    AppSetting.set(key, (!current).to_s)
  end
end
