require 'rails_helper'

describe "POST /confirmations", type: :request do
  context 'with invalid email' do
    before do
      post '/confirmations', params: { confirmation: { email: :invalid_email } }
    end

    it 'returns 422' do
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'with valid email' do
    let(:user) { User.create(name: "user", email: "user@mail.com", password: "user") }

    before do
      post "/confirmations", params: { confirmation: { email: user.email } }
    end

    it 'returns 204' do
      expect(response).to have_http_status(:no_content)
    end

    it 'sends confirmation email to administrators for approval' do
      expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(Settings.admin_email)
    end
  end
end