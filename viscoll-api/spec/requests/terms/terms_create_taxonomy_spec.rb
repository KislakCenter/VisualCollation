require 'rails_helper'

describe "POST /terms/taxonomy", :type => :request do
  before do
    @user = FactoryBot.create(:user, {:password => "user"})
    put "/confirmations/#{@user.confirmation_token}"
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  before :each do
    @project = FactoryBot.create(:project, {user: @user, taxonomies: ["Ink"]})
    @parameters = {
      "taxonomy": {
        "project_id": @project.id.to_str,
        "taxonomy": "Paper"
      }
    }
  end

  context 'with valid authorization' do
    context 'with valid parameters' do
      before do
        post '/terms/taxonomy', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @project.reload
      end

      it 'should return 200' do
        expect(response).to have_http_status(:no_content)
      end

      it 'should add the taxonomy to the project' do
        expect(@project.taxonomies).to include "Ink"
        expect(@project.taxonomies).to include "Paper"
      end
    end

    context 'with missing project' do
      before do
        @parameters[:taxonomy][:project_id] += 'missing'
        post '/terms/taxonomy', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @project.reload
        @body = JSON.parse(response.body)
      end

      it 'should return 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'should return the right error message' do
        expect(@body['error']).to eq "Project not found."
      end
    end

    context 'with duplicated taxonomy' do
      before do
        @parameters[:taxonomy][:taxonomy] = "Ink"
        post '/terms/taxonomy', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @project.reload
        @body = JSON.parse(response.body)
      end

      it 'should return 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'should return the right error message' do
        expect(@body['error']).to eq "Taxonomy (Ink) already exists in the project"
      end

      it 'should leave the project alone' do
        expect(@project.taxonomies).to eq ["Ink"]
      end
    end
    
    context 'with unauthorized project' do
      before do
        @user2 = FactoryBot.create(:user)
        @project2 = FactoryBot.create(:project, {user: @user2, taxonomies: ["Ink"]})
        @parameters[:taxonomy][:project_id] = @project2.id.to_str
        post '/terms/taxonomy', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @project2.reload
      end
      
      it 'should return 403' do
        expect(response).to have_http_status(:forbidden)
      end
      
      it 'should leave the taxonomies alone' do
        expect(@project2.taxonomies).not_to include("Paper")
      end
    end
  end

  context 'with corrupted authorization' do
    before do
      post '/terms/taxonomy', params: @parameters.to_json, headers: {'Authorization' => @authToken+'asdf', 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
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
      post '/terms/taxonomy', params: @parameters.to_json, headers: {'Authorization' => ""}
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
      post '/terms/taxonomy', params: @parameters.to_json, headers: {'Authorization' => "123456789"}
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
      post '/terms/taxonomy'
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
