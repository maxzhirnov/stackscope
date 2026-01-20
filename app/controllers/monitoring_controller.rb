class MonitoringController < ApplicationController
  RUN_DEBOUNCE_SECONDS = 30

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
    return throttled("servers_checks_last_run_at", "Server checks already running.") if throttled?("servers_checks_last_run_at")

    PingAllServersJob.perform_later
    FetchAllMetricsJob.perform_later
    mark_run("servers_checks_last_run_at")
    respond_with_notice("Server checks triggered.")
  end

  def run_shortcuts
    return throttled("shortcuts_checks_last_run_at", "Shortcut checks already running.") if throttled?("shortcuts_checks_last_run_at")

    CheckShortcutsJob.perform_later
    mark_run("shortcuts_checks_last_run_at")
    respond_with_notice("Shortcut checks triggered.")
  end

  private

  def toggle(key)
    current = AppSetting.enabled?(key, default: true)
    AppSetting.set(key, (!current).to_s)
  end

  def throttled?(key)
    last = AppSetting.get(key)
    return false if last.blank?

    Time.current.to_i - last.to_i < RUN_DEBOUNCE_SECONDS
  end

  def mark_run(key)
    AppSetting.set(key, Time.current.to_i)
  end

  def throttled(key, message)
    respond_with_notice(message)
  end

  def respond_with_notice(message)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "toast-container",
          partial: "shared/toast",
          locals: { message: message, type: "notice" }
        )
      end
      format.html { redirect_to root_path, notice: message }
    end
  end
end
