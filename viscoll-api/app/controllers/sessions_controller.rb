class SessionsController < RailsJwtAuth::SessionsController

  def create
    se = RailsJwtAuth::Session.new(session_create_params)

    if se.generate!(request)
      @user = se.user
      @userToken = se.jwt
      @userProjects = []
      begin
        @userProjects = @user.projects
      rescue
      end
      render :index, status: :ok
    else
      render_422 se.errors.details
    end
  end
end
