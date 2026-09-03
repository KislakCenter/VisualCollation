require 'rails_helper'

describe "POST /leafs", :type => :request do
  before do
    @user = FactoryBot.create(:user, {:password => "user"})
    put "/confirmations/#{@user.confirmation_token}"
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  before :each do
    @project = FactoryBot.create(:project, user: @user)
    @group = FactoryBot.create(:group, project: @project)
    @project.add_groupIDs([@group.id.to_s], 0)
    @parameters = {
      "leaf": {
        "project_id": @project.id.to_s,
        "parentID": @group.id.to_s,
        "order": 1,
        "material": "Parchment",
      },
      "additional": {
        "memberOrder": 1,
        "noOfLeafs": 5,
        "conjoin": true,
        "oddMemberLeftOut": 2
      }
    }
  end
  
  it 'should set up properly' do
    expect(true).to be true
  end

  context 'and valid authorization' do
    context 'and standard leaf' do
      before do
        post '/leafs', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @project.reload
        @group.reload
      end

      it 'returns 204' do
        expect(response).to have_http_status(:no_content)
      end

      it 'adds 5 leafs to the project and group' do
        expect(@project.leafs.length).to eq 5
        expect(@group.memberIDs).to eq(@project.leafs.collect { |leaf| leaf.id.to_s })
      end
    end
    
    context 'and missing project' do
      before do
        @parameters[:leaf][:project_id] += "WAAHOO"
        post '/leafs', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @body = JSON.parse(response.body)
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'and invalid additional arguments' do
      before do
        @parameters[:additional][:noOfLeafs] = -1
        post '/leafs', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @body = JSON.parse(response.body)
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'and failing params for the leaf' do
      before do
        allow_any_instance_of(Leaf).to receive(:save).and_return(false)
        post '/leafs', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
    
    context 'and an unauthorized project' do
      before do
        @user2 = FactoryBot.create(:user)
        @project.update(user: @user2)
        post '/leafs', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @project.reload
        @group.reload
      end
      
      it 'returns 403' do
        expect(response).to have_http_status(:forbidden)
      end
      
      it 'should not add leafs to the project' do
        expect(@project.leafs).to be_blank
        expect(@group.memberIDs).to be_blank
      end
    end
  end

  context 'with corrupted authorization' do
    before do
      post '/leafs', params: @parameters.to_json, headers: {'Authorization' => @authToken+'asdf', 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
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
      post '/leafs', params: @parameters.to_json, headers: {'Authorization' => ""}
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
      post '/leafs', params: @parameters.to_json, headers: {'Authorization' => "123456789"}
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
      post '/leafs'
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
