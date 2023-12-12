# frozen_string_literal: true

class ConfirmationsController < ApplicationController
  def update
    if params[:confirmation_token].blank?
      return render_422(confirmation_token: [I18n.t('rails_jwt_auth.errors.not_found')])
    end

    user = RailsJwtAuth.model.where(confirmation_token: params[:confirmation_token]).first
    return render_422(confirmation_token: [I18n.t('rails_jwt_auth.errors.not_found')]) unless user

    if user.confirm!
      AccountApprovalMailer.sendApprovalStatus(user).deliver_now
      render_204
    else
      render_422(user.errors)
    end
  end

  def render_204
    render json: {}, status: :no_content
  end

  def render_422(errors)
    render json: { errors: errors }, status: :unprocessable_entity
  end
end
