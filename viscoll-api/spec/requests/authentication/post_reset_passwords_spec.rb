require 'rails_helper'

describe "POST /reset_passwords", :type => :request do
  context 'with valid params' do
    before do
      @user = User.create(:name => "user", :email => "user@mail.com", :password => "user")
      @user.confirmation_token = nil
      @user.confirmed_at = "2017-07-12T16:08:25.278Z"
      @user.save
      post '/reset_passwords', params: { reset_password: { email: "user@mail.com" } }
    end

    it 'returns a successful no_content response' do
      expect(response).to have_http_status(:no_content)
    end

    it 'creates fields for reset_password in user record' do
      expect(User.find(@user.id).reset_password_token).not_to eq(nil)
      expect(User.find(@user.id).reset_password_sent_at).not_to eq(nil)
    end
  end

  context 'with invalid params' do
    context 'and unconfirmed user' do 
      before do
        @user = User.create(:name => "user", :email => "user@mail.com", :password => "user")
        post '/reset_passwords', params: { reset_password: { email: "user@mail.com" } }
      end

      it 'returns an unprocessable_content status' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an appropriate error message' do
        expect(JSON.parse(response.body)['errors']['email'][0]['error']).to eq('unconfirmed')
      end

      it 'doest not create fields for reset_password in user record' do
        expect(User.find(@user.id).reset_password_token).to eq(nil)
        expect(User.find(@user.id).reset_password_sent_at).to eq(nil)
      end
    end

    context 'and no valid user' do
      before do
        post '/reset_passwords', params: { reset_password: { email: "user@mail.com" } }
      end

      it 'returns 204 to avoid exposing which emails are present' do
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
