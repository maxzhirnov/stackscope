class AddAgentTokenToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :agent_token, :string
  end
end
