class ApplicationMailer < ActionMailer::Base
  # TODO
  default from: Settings.mailer_default_from
  layout 'mailer'
end
