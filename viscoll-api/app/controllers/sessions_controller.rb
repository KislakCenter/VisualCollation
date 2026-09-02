class SessionsController < RailsJwtAuth::SessionsController

  def create
    session = RailsJwtAuth::Session.new(session_create_params)

    if session.generate!(request)
      @user = session.user
      @userToken = session.jwt
      @userProjects = []
      begin
        @userProjects = @user.projects
      rescue
      end
      render :index, status: :ok
    else
      render_422 session.errors.details
    end
  end
end
