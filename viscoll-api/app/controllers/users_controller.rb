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
      raise VCError.new("User update failed", status: :unprocessable_entity, json: current_user.errors)
    end

  end

  # DELETE /users/1
  def destroy
    @user.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = find_document(User, params[:id])

    if (@user != current_user)
      raise VCError.new("Unauthorized. User's do not match.", status: :unauthorized)
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
