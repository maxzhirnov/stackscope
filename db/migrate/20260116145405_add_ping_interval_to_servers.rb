class AddPingIntervalToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :ping_interval_seconds, :integer, default: 60, null: false
  end
end
