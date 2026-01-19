require "net/http"
require "uri"

class CheckShortcutsJob < ApplicationJob
  queue_as :default

  def perform
    return unless AppSetting.enabled?("shortcuts_checks_enabled", default: true)

    now = Time.current
    Shortcut.where(monitor_enabled: true).find_each do |shortcut|
      next unless due?(shortcut, now)

      CheckShortcutJob.perform_later(shortcut.id)
    end
  end

  private

  def due?(shortcut, now)
    return true if shortcut.last_checked_at.blank?

    now - shortcut.last_checked_at >= shortcut.check_interval
  end
end
