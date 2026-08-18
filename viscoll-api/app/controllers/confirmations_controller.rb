class ConfirmationsController < RailsJwtAuth::ConfirmationsController
  # todo: should we inherit from RailsJwtAuth::ConfirmationsController

  def update
    return render_404 unless
      params[:id] &&
      (user = RailsJwtAuth.model.where(confirmation_token: params[:id]).first)

    if user.confirm!
      AccountApprovalMailer.sendApprovalStatus(user).deliver_now
      render_204
    else
      render_422(user.errors.details)
    end
  end
end
