# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Group, type: :model do
  before do
    @project = FactoryGirl.create(:project)
    @group = FactoryGirl.create(:group, project: @project)
    @project.add_groupIDs([@group.id], 0)
  end

  it { is_expected.to be_mongoid_document }

  it { is_expected.to have_field(:title).of_type(String) }
  it { is_expected.to have_field(:type).of_type(String) }
  it { is_expected.to have_field(:tacketed).of_type(Array) }
  it { is_expected.to have_field(:sewing).of_type(Array) }
  it { is_expected.to have_field(:nestLevel).of_type(Integer) }
  it { is_expected.to have_field(:parentID).of_type(String) }
  it { is_expected.to have_field(:memberIDs).of_type(Array) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_and_belong_to_many(:terms) }

  describe 'Initialization' do
    it 'prefixes its ID' do
      expect(@group.id.to_s[0..5]).to eq 'Group_'
    end
  end

  describe 'Member handling' do
    it 'adds member IDs' do
      @group.add_members(%w[abcd efgh], 0)
      expect(@group.memberIDs).to eq %w[abcd efgh]
    end

    it 'adds additional member IDs' do
      @group.add_members(%w[abcd efgh ijkl], 0)
      expect(@group.memberIDs).to eq %w[abcd efgh ijkl]
      @group.add_members(%w[1234 5678], 3)
      expect(@group.memberIDs).to eq %w[abcd efgh 1234 5678 ijkl]
    end

    it 'respects the save flag' do
      @group.add_members(%w[abcd efgh ijkl], 0)
      expect(@group.memberIDs).to eq %w[abcd efgh ijkl]
      @group.add_members(%w[1234 5678], 3, false)
      expect(@group.memberIDs).to eq %w[abcd efgh 1234 5678 ijkl]
      @group.reload
      expect(@group.memberIDs).to eq %w[abcd efgh ijkl]
    end

    it 'removes member IDs' do
      @group.add_members(%w[abcd efgh ijkl], 0)
      expect(@group.memberIDs).to eq %w[abcd efgh ijkl]
      @group.remove_members(%w[abcd ijkl])
      expect(@group.memberIDs).to eq ['efgh']
    end
  end

  describe 'On-destroy hooks' do
    it 'removes itself from an associated term' do
      term = FactoryGirl.create(:term, project: @project,
                                       objects: { Group: [@group.id], Leaf: [], Recto: [], Verso: [] })
      @group.terms << term
      @group.save
      @group.destroy
      expect(term.objects[:Group]).to be_empty
    end

    it 'removes itself from an associated project' do
      @group.destroy
      expect(@project.groupIDs).to be_empty
    end

    it 'removes itself from a parent group' do
      parent_group = FactoryGirl.create(:group, project: @project)
      @project.add_groupIDs([parent_group.id.to_s], 0)
      @group.parentID = parent_group.id
      parent_group.add_members([@group.id.to_s], 0)
      @group.save
      expect(parent_group.memberIDs).not_to be_empty
      @group.destroy
      parent_group.reload
      expect(parent_group.memberIDs).to be_empty
    end

    it 'removes its members' do
      subgroup = FactoryGirl.create(:group, project: @project)
      subgroup_id = subgroup.id
      @project.add_groupIDs([subgroup.id.to_s], 0)
      subgroup.parentID = @group.id
      @group.add_members([subgroup.id.to_s], 0)
      subgroup.save
      expect(@group.memberIDs).to include(subgroup.id.to_s)

      subleaf = FactoryGirl.create(:leaf, project: @project)
      subleaf_id = subleaf.id
      @group.add_members([subleaf.id.to_s], 0)
      subleaf.parentID = @group.id.to_s
      subleaf.save
      expect(@group.memberIDs).to include(subleaf.id.to_s)

      @group.destroy
      expect(described_class.where(id: subgroup_id).exists?).to be false
      expect(Leaf.where(id: subleaf_id).exists?).to be false
    end
  end
end
