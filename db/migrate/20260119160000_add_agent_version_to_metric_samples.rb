class AddAgentVersionToMetricSamples < ActiveRecord::Migration[8.0]
  def change
    add_column :metric_samples, :agent_version, :string
  end
end
