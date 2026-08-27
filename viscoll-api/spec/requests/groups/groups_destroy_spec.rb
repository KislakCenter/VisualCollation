require 'rails_helper'

describe "DELETE /groups/id", :type => :request do
  before do
    @user = FactoryBot.create(:user, {:password => "user"})
    put "/confirmations/#{@user.confirmation_token}"
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  before :each do
    @project = FactoryBot.create(:project, {
      user: @user,
      taxonomies: ["Ink"],
    })
    @groupIDs = []
    5.times do |n|
      group = FactoryBot.create(:quire, { project: @project })
      @groupIDs.push(group.id.to_s)
    end
    @group = @project.groups.find(@groupIDs[3])
    @project.add_groupIDs(@groupIDs, 0)
    @parameters = {
      projectID: @project.id.to_s,
      group: {
        type: "Booklet",
        title: "Changed title"
      },
    }
  end

  context 'with valid authorization' do
    context 'and standard group specs' do
      before do
        delete "/groups/#{@group.id.to_str}", params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @project.reload
      end

      it 'returns 204' do
        expect(response).to have_http_status(:no_content)
      end

      it 'destroys the group' do
        expect(@project.groups).not_to include an_object_having_attributes(id: @group.id)
      end
    end

    context 'and missing group' do
      before do
        delete "/groups/#{@group.id.to_str}missing", params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @body = JSON.parse(response.body)
      end

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns the right error message' do
        expect(@body['error']).to include "Group not found"
      end
    end

    context 'and unauthorized group' do
      before do
        @project.user = FactoryBot.create(:user)
        @project.save
        delete "/groups/#{@group.id.to_str}", params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @body = JSON.parse(response.body)
        @group.reload
      end

      it 'returns 403' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns the error message' do
        expect(@body['error']).to include "Project is not authorized"
      end

      it 'retains the group' do
        expect(@project.groups).to include an_object_having_attributes(id: @group.id)
      end
    end

    context 'and raised exception' do
      before do
        allow_any_instance_of(Group).to receive(:destroy).and_raise(StandardError)
        delete "/groups/#{@group.id.to_str}", params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @body = JSON.parse(response.body)
      end

      it 'returns 500' do
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns the error message' do
        expect(@body['errors']).to eq 'StandardError'
      end
    end
  end

  context 'with corrupted authorization' do
    before do
      delete "/groups/#{@group.id.to_str}", params: @parameters.to_json, headers: {'Authorization' => @authToken+'asdf', 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
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
      delete "/groups/#{@group.id.to_str}", params: @parameters.to_json, headers: {'Authorization' => ""}
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
      delete "/groups/#{@group.id.to_str}", params: @parameters.to_json, headers: {'Authorization' => "123456789"}
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
      delete "/groups/#{@group.id.to_str}"
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
