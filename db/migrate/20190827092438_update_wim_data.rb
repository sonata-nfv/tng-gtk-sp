class UpdateWimData < ActiveRecord::Migration[5.2]
  def change
    add_column :infrastructure_requests, :wim_list, :string, default: '[]'
    remove_column :infrastructure_requests, :name
    remove_column :infrastructure_requests, :attached_vims
    remove_column :infrastructure_requests, :attached_endpoints
  end
end
