class AddIndexOnInstanceUuidAndRequestType < ActiveRecord::Migration[5.2]
  def change
    add_index :requests, [:instance_uuid, :request_type]
    add_index :requests, :updated_at
  end
end
