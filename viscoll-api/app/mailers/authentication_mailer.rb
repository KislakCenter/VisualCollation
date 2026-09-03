# Overriding confirmation_instructions in RailsJwtAuth::Mailer so we can send
# confirmation emails to administrators for approval.
class AuthenticationMailer < RailsJwtAuth::Mailer
  def confirmation_instructions
    raise RailsJwtAuth::NotConfirmationsUrl unless RailsJwtAuth.confirm_email_url.present?

    @confirm_email_url = add_param_to_url(
      RailsJwtAuth.confirm_email_url,
      'confirmation_token',
      @user.confirmation_token
    )

    # Sending confirmation email to administrator instead of User, so accounts can be confirmed.
    mail(to: Settings.admin_email, subject: @subject)
  end
end
