class CreateServers < ActiveRecord::Migration[8.0]
  def change
    create_table :servers do |t|
      t.string :name
      t.string :host
      t.string :agent_url
      t.string :status
      t.datetime :last_ping_at
      t.datetime :last_metrics_at

      t.timestamps
    end
  end
end
