class AddScalingRequestFields < ActiveRecord::Migration[5.2]
  def change
    add_column :requests, :scaling_type, :string
    add_column :requests, :vim_uuid, :string
    add_column :requests, :number_of_instances, :string
    add_column :requests, :duration, :float, default: 0.0
    add_column :requests, :vnfd_uuid, :string
    add_column :requests, :function_uuids, :string
  end
end
