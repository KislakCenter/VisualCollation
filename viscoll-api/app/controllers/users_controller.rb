# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate!
  before_action :set_user, only: %i[show update destroy]

  # GET /users/1
  def show; end

  # PATCH/PUT /users/1
  def update
    action = if !user_params_with_password[:password].nil?
               current_user.update_with_password(user_params_with_password)
             else
               current_user.update(user_params)
             end
    raise VCError, "User update failed: #{current_user.errors.full_messages.join "\n"}" unless action

    @user = User.find(params[:id])
    render :show, status: :ok and return
  end

  # DELETE /users/1
  def destroy
    @user.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
    return unless @user != current_user

    raise VCError, "Unauthorized. User's do not match."
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
