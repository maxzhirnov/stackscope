class AddPingLatencyToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :ping_latency_ms, :integer
  end
end
