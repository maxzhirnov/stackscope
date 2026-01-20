class AddExtendedMetricsToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :extended_metrics_json, :text
    add_column :servers, :extended_metrics_fetched_at, :datetime
  end
end
