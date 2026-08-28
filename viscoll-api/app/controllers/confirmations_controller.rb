class ConfirmationsController < RailsJwtAuth::ConfirmationsController
  def update
    return render_404 unless @user

    if @user.confirm
      AccountApprovalMailer.sendApprovalStatus(@user).deliver_now
      render_204
    else
      render_422(@user.errors.details)
    end
  end
end
