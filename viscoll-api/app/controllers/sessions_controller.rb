class SessionsController < RailsJwtAuth::SessionsController

  def create
    user = find_user

    if !user
      render_422 session: [{error: :invalid_session}]
    elsif user.respond_to?('confirmed?') && !user.confirmed?
      render_422 session: [{error: :unconfirmed}]
    elsif user.authentication?(session_create_params[:password])
      @userProjects = []
      begin
        @userProjects = user.projects
      rescue
      end
      @userToken = generate_jwt(user)
      @user = user
      render :index, status: :ok, location: {
        userProjects: @userProjects,
        userToken: @userToken,
        user: @user
      }
    else
      render_422 session: [user.unauthenticated_error]
    end
  end

  # def destroy
  #   return render_404 unless RailsJwtAuth.simultaneous_sessions > 0
  #
  #   authenticate!
  #   payload = RailsJwtAuth::JwtManager.decode_from_request(request)&.first
  #   current_user.destroy_auth_token payload['auth_token']
  #   render_204


    # begin
    #   authenticateDestroy!
    #   current_user.destroy_auth_token Jwt::Request.new(request).auth_token
    #   render_204
    # rescue JWT::DecodeError, JWT::EncodeError => e
    #   render json: { error: "Authorization Header: #{e.message}" }, status: :unprocessable_entity
    # end
  # end
end

# module Jwt
#   class Request
#     def initialize(request)
#       return unless request.env['HTTP_AUTHORIZATION']
#       @jwt = request.env['HTTP_AUTHORIZATION'].split.last
#
#       begin
#         @jwt_info = RailsJwtAuth::Jwt::Manager.decode(@jwt)
#       rescue JWT::ExpiredSignature, JWT::VerificationError
#         @jwt_info = false
#       end
#     end
#
#     def valid?
#       @jwt && @jwt_info && RailsJwtAuth::Jwt::Manager.valid_payload?(payload)
#     end
#
#     def payload
#       @jwt_info ? @jwt_info[0] : nil
#     end
#
#     def header
#       @jwt_info ? @jwt_info[1] : nil
#     end
#
#     def auth_token
#       payload ? payload['auth_token'] : nil
#     end
#   end
# end
