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
end
