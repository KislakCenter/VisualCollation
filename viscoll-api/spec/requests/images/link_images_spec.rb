require 'rails_helper'

describe "PUT /images/link", :type => :request do
  before do
    @user = FactoryGirl.create(:user, {:password => "user"})
    put '/confirmation', params: {:confirmation_token => @user.confirmation_token}
    post '/session', params: {:session => { :email => @user.email, :password => "user" }}
    @authToken = JSON.parse(response.body)['session']['jwt']
  end

  before :each do
    @project1 = FactoryGirl.create(:project, user: @user)
    @project2 = FactoryGirl.create(:project, user: @user)
    @image1 = FactoryGirl.create(:pixel, user: @user)
    @image2 = FactoryGirl.create(:shiba_inu, user: @user)
    @parameters = {
    	"projectIDs": [],
    	"imageIDs": []
    }
  end
  
  context 'with valid authorization' do
    context 'and valid image and project' do
      before do
        @parameters[:projectIDs] = [@project1.id.to_s]
        @parameters[:imageIDs] = [@image1.id.to_s]
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @body = JSON.parse(response.body)
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'establishes the link' do
        expect(@image1.projectIDs).to include @project1.id.to_s
      end
    end
    
    context 'and multiple valid images and multiple projects' do
      before do
        @parameters[:projectIDs] = [@project1.id.to_s, @project2.id.to_s]
        @parameters[:imageIDs] = [@image1.id.to_s, @image2.id.to_s]
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @image2.reload
        @body = JSON.parse(response.body)
      end

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'establishes the link' do
        expect(@image1.projectIDs).to include @project1.id.to_s
        expect(@image1.projectIDs).to include @project2.id.to_s
        expect(@image2.projectIDs).to include @project1.id.to_s
        expect(@image2.projectIDs).to include @project2.id.to_s
      end
    end
    
    context 'and valid image but missing project' do
      before do
        @parameters[:projectIDs] = [@project1.id.to_s, @project2.id.to_s+'missing']
        @parameters[:imageIDs] = [@image1.id.to_s, @image2.id.to_s]
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @image2.reload
        @body = JSON.parse(response.body)
      end

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'shows the error' do
        expect(@body['error']).to eq "project not found with id #{@project2.id}missing"
      end
      
      it 'leaves the images alone' do
        expect(@image1.projectIDs).to be_empty
        expect(@image2.projectIDs).to be_empty
      end
    end
    
    context 'and valid image but unauthorized project' do
      before do
        @project2.update(user: FactoryGirl.create(:user))
        @parameters[:projectIDs] = [@project1.id.to_s, @project2.id.to_s]
        @parameters[:imageIDs] = [@image1.id.to_s, @image2.id.to_s]
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @image2.reload
      end

      it 'returns 401' do
        expect(response).to have_http_status(:unauthorized)
      end
      
      it 'leaves the images alone' do
        expect(@image1.projectIDs).to be_empty
        expect(@image2.projectIDs).to be_empty
      end
    end
    
    context 'and missing image but valid project' do
      before do
        @parameters[:projectIDs] = [@project1.id.to_s, @project2.id.to_s]
        @parameters[:imageIDs] = [@image1.id.to_s, @image2.id.to_s+'missing']
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @image2.reload
        @body = JSON.parse(response.body)
      end

      it 'returns 404' do
        expect(response).to have_http_status(:not_found)
      end

      it 'shows the error' do
        expect(@body['error']).to eq "image not found with id #{@image2.id}missing"
      end
      
      it 'leaves the images alone' do
        expect(@image1.projectIDs).to be_empty
        expect(@image2.projectIDs).to be_empty
      end
    end
    
    context 'and unauthorized image but valid project' do
      before do
        @image2.update(user: FactoryGirl.create(:user))
        @parameters[:projectIDs] = [@project1.id.to_s, @project2.id.to_s]
        @parameters[:imageIDs] = [@image1.id.to_s, @image2.id.to_s]
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @image2.reload
      end

      it 'returns 401' do
        expect(response).to have_http_status(:unauthorized)
      end
      
      it 'leaves the images alone' do
        expect(@image1.projectIDs).to be_empty
        expect(@image2.projectIDs).to be_empty
      end
    end
    
    context 'and exception in projects' do
      before do
        allow(Project).to receive(:find).and_raise('waahooexception')
        @parameters[:projectIDs] = [@project1.id.to_s]
        @parameters[:imageIDs] = [@image1.id.to_s]
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @body = JSON.parse(response.body)
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end
      
      it 'shows the error' do
        expect(@body['error']).to eq 'waahooexception'
      end
      
      it 'leaves the images alone' do
        expect(@image1.projectIDs).to be_empty
        expect(@image2.projectIDs).to be_empty
      end
    end
    
    context 'and exception in images' do
      before do
        allow(Image).to receive(:find).and_raise('waahooexception')
        @parameters[:projectIDs] = [@project1.id.to_s]
        @parameters[:imageIDs] = [@image1.id.to_s]
        put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken, 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
        @image1.reload
        @body = JSON.parse(response.body)
      end

      it 'returns 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end
      
      it 'shows the error' do
        expect(@body['error']).to eq 'waahooexception'
      end
      
      it 'leaves the images alone' do
        expect(@image1.projectIDs).to be_empty
        expect(@image2.projectIDs).to be_empty
      end
    end
  end
  
  context 'with corrupted authorization' do
    before do
      put '/images/link', params: @parameters.to_json, headers: {'Authorization' => @authToken+'asdf', 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json'}
      @body = JSON.parse(response.body)
    end

    it 'returns an bad request error' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns an appropriate error message' do
      expect(JSON.parse(response.body)['error']).to eq('Authorization Token: Signature verification raised')
    end
  end

  context 'with empty authorization' do
    before do
      put '/images/link', params: @parameters.to_json, headers: {'Authorization' => ""}
    end

    it 'returns an bad request error' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns an appropriate error message' do
      expect(JSON.parse(response.body)['error']).to eq('Authorization Token: Nil JSON web token')
    end
  end

  context 'invalid authorization' do
    before do
      put '/images/link', params: @parameters.to_json, headers: {'Authorization' => "123456789"}
    end

    it 'returns an bad request error' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns an appropriate error message' do
      expect(JSON.parse(response.body)['error']).to eq('Authorization Token: Not enough or too many segments')
    end
  end

  context 'without authorization' do
    before do
      put '/images/link'
    end

    it 'returns an unauthorized action error' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
  
