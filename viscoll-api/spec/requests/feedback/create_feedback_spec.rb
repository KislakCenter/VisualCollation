require 'rails_helper'

describe "POST /feedback", :type => :request do
  before do
    @user = FactoryGirl.create(:user, {:password => "user"})
    put "/confirmations/#{@user.confirmation_token}"
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  before :each do
    @parameters = {
      feedback: {
        title: "Something is weird",
        message: "Hey can you look into this"
      }
    }
  end

  context 'with valid authentication' do
    context 'and valid user ID' do
      it 'sends an email' do
        expect {
          post '/feedback', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        }.to change { ActionMailer::Base.deliveries.count }.by 1
      end

      it 'requires a title' do
        @parameters[:feedback][:title] = ''
        post '/feedback', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq 'Title and message required.'
      end

      it 'requires a message' do
        @parameters[:feedback][:message] = ''
        post '/feedback', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq 'Title and message required.'
      end

      it 'handles exceptions' do
        expect(FeedbackMailer).to receive(:sendFeedback).and_raise(StandardError, 'AnException')
        post '/feedback', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)['errors']).to eq 'AnException'
      end
    end
  end

  context 'with corrupted authorization' do
    before do
      post '/feedback', params: @parameters.to_json, headers: {'Authorization' => @authToken+'asdf', 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
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
      post '/feedback', params: @parameters.to_json, headers: {'Authorization' => ""}
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
      post '/feedback', params: @parameters.to_json, headers: {'Authorization' => "123456789"}
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
      post '/feedback'
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
