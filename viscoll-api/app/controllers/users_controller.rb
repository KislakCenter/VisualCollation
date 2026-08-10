class UsersController < ApplicationController
  before_action :authenticate!
  before_action :set_user, only: [:show, :update, :destroy]

  # GET /users/1
  def show
  end

  # PATCH/PUT /users/1
  def update
    if user_params_with_password[:password] != nil
      action = current_user.update_with_password(user_params_with_password)
    else
      action = current_user.update_attributes(user_params)
    end
    if action
      @user = User.find(params[:id])
      render :show, status: :ok and return
    else
      render json: { error: "User update failed: #{current_user.errors.full_messages.to_sentence}"} , status: :unprocessable_entity
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    begin
      @user = User.find(params[:id])

    rescue Mongoid::Errors::DocumentNotFound
      render(json: { error: "User not found" }, status: :not_found) and return
    end

    if (@user != current_user)
      render json: { error: "Unauthorized." }, status: :forbidden
    end
  end

  # Only allow a trusted parameter "white list" through.
  def user_params
    params.require(:user).permit(:email, :name)
  end

  # Only allow a trusted parameter "white list" through.
  def user_params_with_password
    params.require(:user).permit(:email, :name, :current_password, :password)
  end
end
