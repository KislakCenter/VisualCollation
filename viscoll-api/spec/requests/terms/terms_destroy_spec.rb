require 'rails_helper'

describe "DELETE /terms/id", :'type' => :request do
  before do
    @user = FactoryBot.create(:user, {:password => "user"})
    put "/confirmations/#{@user.confirmation_token}"
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  before :each do
    @project = FactoryBot.create(:project, {
        user: @user,
        taxonomies: ["Ink"]
    })
    @term = FactoryBot.create(:term, {
        taxonomy: "Ink",
      project: @project
    })
    @parameters = {}
  end

  context 'with valid authorization' do
    context 'and valid term ID' do
      before do
        delete '/terms/'+@term.id, params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      end

      it 'returns 204' do
        expect(response).to have_http_status(:no_content)
      end

      it 'deletes the term' do
        expect(Term.where(id: @term.id).exists?).to be false
      end
    end

    context 'and invalid term ID' do
      before do
        delete '/terms/'+@term.id+'invalid', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      end

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "and someone else's terms" do
      before do
        @user2 = FactoryBot.create(:user)
        @project2 = FactoryBot.create(:project, {
            user: @user2,
            taxonomies: ["Hand"]
        })
        @term2 = FactoryBot.create(:term, {
            taxonomy: "Hand",
          project: @project2
        })
        delete '/terms/'+@term2.id, params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      end

      it 'returns 403' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'leaves the term alone' do
        expect(Term.where(id: @term2.id).exists?).to be true
      end
    end
  end

  context 'with corrupted authorization' do
    before do
      delete '/terms/'+@term.id, params: @parameters.to_json, headers: {'Authorization' => @authToken+'asdf', 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
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
      delete '/terms/'+@term.id, params: @parameters.to_json, headers: {'Authorization' => ""}
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
      delete '/terms/'+@term.id, params: @parameters.to_json, headers: {'Authorization' => "123456789"}
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
      delete '/terms/'+@term.id
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
