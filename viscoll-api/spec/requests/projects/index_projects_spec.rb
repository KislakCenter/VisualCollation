require 'rails_helper'

describe "GET /projects", :type => :request do
  before do
    @user = FactoryBot.create(:user, {:password => "user"})
    put "/confirmations/#{@user.confirmation_token}"
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  context 'with correct authorization' do
    context 'and standard params' do
      before do
        @user2 = FactoryBot.create(:user)
        @project1 = FactoryBot.create(:project, {:user_id => @user.id})
        @project2 = FactoryBot.create(:project, {:user_id => @user.id})
        @project3 = FactoryBot.create(:project, {:user_id => @user2.id})
        get '/projects', params: '', headers: {'Authorization' => @authToken}
        @body = JSON.parse(response.body)
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it "contains the user's own projects only" do
        expect(@body["projects"].length).to eq 2
        expect(@body["projects"][0]['id']).to eq @project2.id.to_str
        expect(@body["projects"][1]['id']).to eq @project1.id.to_str
      end
    end
  end

  context 'with corrupted authorization' do
    before do
      get '/projects', params: '', headers: {'Authorization' => @authToken+"invalid"}
      @body = JSON.parse(response.body)
    end

    it 'returns 401' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns an appropriate error message' do
      expect(JSON.parse(response.body)['error']).to eq('Not Authorized')
    end
  end

  context 'with empty authorization' do
    before do
      get '/projects', params: '', headers: {'Authorization' => ""}
    end

    it 'returns 401' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns an appropriate error message' do
      expect(JSON.parse(response.body)['error']).to eq('Not Authorized')
    end
  end

  context 'invalid authorization' do
    before do
      get '/projects', params: '', headers: {'Authorization' => "123456789"}
    end

    it 'returns 401' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns an appropriate error message' do
      expect(JSON.parse(response.body)['error']).to eq('Not Authorized')
    end
  end

  context 'without authorization' do
    before do
      get '/projects'
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
