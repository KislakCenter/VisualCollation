class UsersController < ApplicationController
  before_action :authenticate!
  before_action :set_user, only: [:show, :update, :destroy]

  # GET /users/1
  def show
  end

  # PATCH/PUT /users/1
  def update
    if update_email_params.include?(:email)
      action = current_user.update_email(update_email_params)
    elsif update_password_params.include?(:password)
      action = current_user.update_password(update_password_params)
    else
      action = current_user.update_attributes(user_params)
    end

    if action
      @user = User.find(params[:id])
      render :show, status: :ok and return
    else
      render json: { error: current_user.errors.details }, status: :unprocessable_content
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
    params.require(:user).permit(:name)
  end

  def update_email_params
    params.require(:user).permit(:email, :password)
  end

  # Only allow a trusted parameter "white list" through.
  def update_password_params
    params.require(:user).permit(:current_password, :password)
  end
end
