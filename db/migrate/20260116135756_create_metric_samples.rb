class CreateMetricSamples < ActiveRecord::Migration[8.0]
  def change
    create_table :metric_samples do |t|
      t.references :server, null: false, foreign_key: true
      t.decimal :cpu_usage
      t.decimal :memory_usage
      t.decimal :disk_usage
      t.decimal :load_avg
      t.datetime :collected_at

      t.timestamps
    end
  end
end
