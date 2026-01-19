class AddExtendedMetricsToMetricSamples < ActiveRecord::Migration[8.0]
  def change
    add_column :metric_samples, :uptime_seconds, :integer
    add_column :metric_samples, :swap_usage, :decimal
    add_column :metric_samples, :disk_read_bps, :integer
    add_column :metric_samples, :disk_write_bps, :integer
    add_column :metric_samples, :net_rx_bps, :integer
    add_column :metric_samples, :net_tx_bps, :integer
    add_column :metric_samples, :fs_usage_json, :text
  end
end
