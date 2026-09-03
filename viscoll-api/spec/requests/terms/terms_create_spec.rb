require 'rails_helper'

describe "POST /terms", :type => :request do
  before do
    @user = FactoryBot.create(:user, {:password => "user"})
    put "/confirmations/#{@user.confirmation_token}"
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  before :each do
    @project = FactoryBot.create(:project, {user: @user, taxonomies: ["Ink"]})
    @parameters = {
        term: {
        "project_id": @project.id.to_str,
        "title": "some title for term",
        "taxonomy": "Ink",
        "description": "blue ink"
      }
    }
  end

  context 'and valid authorization' do
    context 'and standard terms' do
      before do
        post '/terms', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      end

      it 'returns 204' do
        expect(response).to have_http_status(:no_content)
      end

      it 'adds a term to the project' do
        expect(@project.terms.length).to eq 1
        expect(@project.terms[0].title).to eq "some title for term"
      end
    end

    context 'and out-of-context terms' do
      before do
        @parameters[:term][:taxonomy] = "WAAHOO"
        post '/terms', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @body = JSON.parse(response.body)
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error message' do
        expect(@body['error']).to eq("Taxonomy (WAAHOO) does not belong to project.")
      end
    end

    context 'and missing project' do
      before do
        @parameters[:term][:project_id] += "WAAHOO"
        post '/terms', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @body = JSON.parse(response.body)
      end

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'gives the right error message' do
        expect(@body['error']).to eq "Project not found."
      end
    end

    context 'and failing params for the term' do
      before do
        allow_any_instance_of(Term).to receive(:save).and_return(false)
        post '/terms', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'and an unauthorized project' do
      before do
        @user2 = FactoryBot.create(:user)
        @project2 = FactoryBot.create(:project, { user: @user2, taxonomies: ["Ink"] })
        @parameters[:term][:project_id] = @project2.id.to_str
        post '/terms', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      end

      it 'returns 403' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'should not add terms to the project' do
        expect(@project2.terms).not_to include an_object_having_attributes({ title: "some title for term" })
      end
    end
  end

  context 'with corrupted authorization' do
    before do
      post '/terms', params: @parameters.to_json, headers: {'Authorization' => @authToken+'asdf', 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
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
      post '/terms', params: @parameters.to_json, headers: {'Authorization' => ""}
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
      post '/terms', params: @parameters.to_json, headers: {'Authorization' => "123456789"}
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
      post '/terms'
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
