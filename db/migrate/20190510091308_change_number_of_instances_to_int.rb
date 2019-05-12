class ChangeNumberOfInstancesToInt < ActiveRecord::Migration[5.2]
  def change
    change_column :requests, :number_of_instances, 'integer USING CAST(number_of_instances AS integer)'
    add_column :requests, :vnf_uuid, :string
  end
end
