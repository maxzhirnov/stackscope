class AddMonitoringToShortcuts < ActiveRecord::Migration[8.0]
  def change
    add_column :shortcuts, :monitor_enabled, :boolean, default: true, null: false
    add_column :shortcuts, :check_interval_seconds, :integer, default: 60, null: false
    add_column :shortcuts, :last_checked_at, :datetime
    add_column :shortcuts, :last_status, :string
    add_column :shortcuts, :last_status_code, :integer
  end
end
