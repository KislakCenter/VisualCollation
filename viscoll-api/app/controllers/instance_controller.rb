class InstanceController < ApplicationController
  def getInstance
    instance_hash = {current_instance: ENV['INSTANCE']}
    render json: instance_hash, status: :ok
  end
end