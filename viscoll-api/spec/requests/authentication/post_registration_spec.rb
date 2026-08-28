require 'rails_helper'

describe "POST /registration", :type => :request do
  context 'with valid params' do
    before do
      post '/registration', params: {:user => { :email=> "user@mail.com", :password => "user", :name=>"user" }}
    end

    it 'returns with a successful 200 response' do
      expect(response).to have_http_status(:created)
    end

    it 'returns an user object in the response body' do
      expect(JSON.parse(response.body)['user']).not_to be_empty
      expect(JSON.parse(response.body)['user']['email']).to eq('user@mail.com')
      expect(JSON.parse(response.body)['user']['name']).to eq('user')
    end

    it 'returns an email confirmation token with the response body' do
      expect(JSON.parse(response.body)['user']['confirmation_token']).not_to be_empty
      expect(JSON.parse(response.body)['user']['confirmation_sent_at']).not_to be_empty
    end

    it 'creates an User object in the database' do
      expect(User.count).to eq(1)
    end

    it 'sends confirmation email to administrators for approval' do
      expect(ActionMailer::Base.deliveries.last.to).to contain_exactly(Rails.application.secrets.admin_email)
    end
  end

  context 'with invalid params' do
    before do
      @user = User.create(:name => "user", :email => "user@mail.com", :password => "user")
      @user.confirmation_token = nil
      @user.confirmed_at = "2017-07-12T16:08:25.278Z"
      @user.save
    end

    context 'where email is empty' do
      before do
        post '/registration', params: {:user => { :email=> "", :password => "newUser", :name=>"newUser" }}
      end
    
      it 'returns an appropriate error messages with 422 code' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['email'].pluck('error')).to eq(['blank', 'invalid'])
      end

      it 'does not create another User object in the database' do
        expect(User.count).to eq(1)
      end
    end

    context 'where email is invalid' do
      before do
        post '/registration', params: {:user => { :email=> "ghost", :password => "newUser", :name=>"newUser" }}
      end
    
      it 'returns an appropriate error message with 422 code' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['email'][0]['error']).to eq('invalid')
      end

      it 'does not create another User object in the database' do
        expect(User.count).to eq(1)
      end
    end

    context 'where email is already taken' do
      before do
        post '/registration', params: {:user => { :email=> "user@mail.com", :password => "user", :name=>"user" }}
      end
    
      it 'returns an appropriate error message with 422 code' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['email'][0]['error']).to eq('taken')
      end

      it 'does not create another User object in the database' do
        expect(User.count).to eq(1)
      end
    end

    context 'where password is empty' do
      before do
        post '/registration', params: {:user => { :email=> "newUser@mail.com", :password => "", :name=>"newUser" }}
      end
    
      it 'returns an appropriate error message with 422 code' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['password'][0]['error']).to eq('blank')
      end

      it 'does not create another User object in the database' do
        expect(User.count).to eq(1)
      end
    end

    context 'where email and password are invalid' do
      before do
        post '/registration', params: {:user => { :email=> "ghost", :password => "", :name=>"newUser" }}
      end
    
      it 'returns an appropriate error message with 422 code' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['email'][0]['error']).to eq('invalid')
        expect(JSON.parse(response.body)['errors']['password'][0]['error']).to eq('blank')
      end

      it 'does not create another User object in the database' do
        expect(User.count).to eq(1)
      end
    end
  end
end
