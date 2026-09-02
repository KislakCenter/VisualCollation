class ApplicationController < ActionController::API
    include RailsJwtAuth::AuthenticableHelper

    # Catching all unexpected errors, logging them and rendering json error for user.
    rescue_from StandardError do |e|
        request.session # initialize session object to avoid error see: https://github.com/rails/rails/issues/43922
        # and https://github.com/sul-dlss-deprecated/dor_indexing_app/pull/769
        Honeybadger.notify(e)
        Rails.logger.error(e.message + "\n" + e.backtrace.join("\n"))
        render json: { errors: e.message }, status: :internal_server_error
    end

    # Catch unauthorized errors.
    rescue_from RailsJwtAuth::NotAuthorized do
        render json: { error: 'Not Authorized' }, status: :unauthorized
    end

    before_action :set_base_api_url
    def set_base_api_url
      # TODO: we need an env var with a complete URL for this
      @base_api_url = Rails.application.secrets.api_url ? Rails.application.secrets.api_url : "https://#{ENV['APPLICATION_HOST']}"
    end

    include ControllerHelper::ProjectsHelper
    include ControllerHelper::GroupsHelper
    include ControllerHelper::LeafsHelper
    include ControllerHelper::FilterHelper
    include ControllerHelper::ImportJsonHelper
    include ControllerHelper::ImportXmlHelper
    include ControllerHelper::ImportMappingHelper
    include ControllerHelper::ExportHelper
    include ValidationHelper::ProjectValidationHelper
    include ValidationHelper::GroupValidationHelper
    include ValidationHelper::LeafValidationHelper
end
