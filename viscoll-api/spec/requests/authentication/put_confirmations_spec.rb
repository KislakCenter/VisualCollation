require 'rails_helper'

describe "PUT /confirmations", :type => :request do
  context 'with invalid token' do
    before do
      put '/confirmations/invalidToken'
    end

    it 'returns 404' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'with valid token' do
    before do
      @user = User.create(:name => "user", :email => "user@mail.com", :password => "user")
      put "/confirmations/#{@user.confirmation_token}"
    end

    it 'returns successful response code' do
      expect(response).to have_http_status(:no_content)
    end

    it 'clears the confirmation token in user record' do
      expect(User.find(@user.id).confirmation_token).to eq(nil)
    end

    it 'send account approval email to user' do
      expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(@user.email)
    end
  end
end
