require 'rails_helper'

RSpec.describe Side, type: :model do
  it { is_expected.to be_mongoid_document }

  it { is_expected.to have_field(:texture).of_type(String) }
  it { is_expected.to have_field(:script_direction).of_type(String) }
  it { is_expected.to have_field(:image).of_type(Hash) }
  it { is_expected.to have_field(:parentID).of_type(String) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_and_belong_to_many(:terms) }

  before :each do
    @user = FactoryGirl.create(:user)
    @project = FactoryGirl.create(:project, user: @user)
    @leaf = FactoryGirl.create(:leaf, project: @project)
    @side = Side.find(id: @leaf.rectoID)
  end

  describe "Destruction hooks" do
    it "should unlink attached terms" do
      term = FactoryGirl.create(:term, project: @project, objects: {Group: [], Leaf: [], Recto: [@side.id.to_s], Verso: []} )
      term2 = FactoryGirl.create(:term, project: @project, objects: {Group: [], Leaf: [], Recto: [], Verso: [@side.id.to_s]} )
      @side.terms << [term, term2]
      @side.save
      expect(@side.terms).to include term
      expect(@side.terms).to include term2
      @side.destroy
      expect(term.objects[:Recto]).to be_empty
      expect(term2.objects[:Verso]).to be_empty
    end

    it "should unlink attached image" do
      image = FactoryGirl.create(:pixel, user: @user, filename: 'pixel.png', projectIDs: [@project.id.to_s], sideIDs: [@side.id.to_s])
      @side.update(image: { url: "http://127.0.0.1:12345/images/#{image.id}_pixel.png", label: 'Pixel', manifestID: 'DIYImages' })
      @side.destroy
      image.reload
      expect(image.sideIDs).to be_empty
    end
  end
end
