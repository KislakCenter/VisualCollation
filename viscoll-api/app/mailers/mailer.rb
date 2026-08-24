if defined?(ActionMailer)
  # Overriding entire Mailer so we can send confirmation emails to administrators for approval.
  class RailsJwtAuth::Mailer < ApplicationMailer
    default from: RailsJwtAuth.mailer_sender

    before_action do
      @user = RailsJwtAuth.model.find(params[:user_id])
      @subject = I18n.t("rails_jwt_auth.mailer.#{action_name}.subject")
    end

    def confirmation_instructions
      raise RailsJwtAuth::NotConfirmationsUrl unless RailsJwtAuth.confirmations_url.present?

      @confirmations_url = add_param_to_url(
        RailsJwtAuth.confirmations_url,
        'confirmation_token',
        @user.confirmation_token
      )

      # Sending confirmation email to administrator instead of User, so accounts can be confirmed.
      mail(to: Rails.application.secrets.admin_email, subject: @subject)
    end

    def reset_password_instructions
      raise RailsJwtAuth::NotResetPasswordsUrl unless RailsJwtAuth.reset_passwords_url.present?

      @reset_passwords_url = add_param_to_url(
        RailsJwtAuth.reset_passwords_url,
        'reset_password_token',
        @user.reset_password_token
      )

      mail(to: @user[RailsJwtAuth.email_field_name], subject: @subject)
    end

    def set_password_instructions
      raise RailsJwtAuth::NotSetPasswordsUrl unless RailsJwtAuth.set_passwords_url.present?

      @reset_passwords_url = add_param_to_url(
        RailsJwtAuth.set_passwords_url,
        'reset_password_token',
        @user.reset_password_token
      )

      mail(to: @user[RailsJwtAuth.email_field_name], subject: @subject)
    end

    def add_param_to_url(url, param_name, param_value)
      path, params = url.split '?'
      params = params ? params.split('&') : []
      params.push("#{param_name}=#{param_value}")
      "#{path}?#{params.join('&')}"
    end
  end
end