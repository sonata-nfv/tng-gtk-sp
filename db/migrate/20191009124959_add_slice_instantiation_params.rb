class AddSliceInstantiationParams < ActiveRecord::Migration[5.2]
  def change
    add_column :requests, :instantiation_params, :text, default: '[]', serialize: JSON
  end
end
