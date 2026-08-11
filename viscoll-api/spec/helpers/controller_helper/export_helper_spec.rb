require 'rails_helper'

RSpec.describe ControllerHelper::ExportHelper, type: :helper do
  before do
    @project = FactoryGirl.create(:project,
      'title' => 'Sample project',
      'shelfmark' => 'Ravenna 384.2339',
      'notationStyle' => 'r-v',
      'metadata' => { date: '18th century' },
      'preferences' => { 'showTips' => true },
      'taxonomies' => ['Ink', 'Unknown'],
      'manifests' => { '12341234': { 'id' => '12341234', 'url' => 'https://digital.library.villanova.edu/Item/vudl:99213/Manifest', 'name' => 'Boston, and Bunker Hill.' } }
    )
    # Attach group with 2 leafs - (group with 2 leafs) - 2 conjoined leafs
    @testgroup = FactoryGirl.create(:group, project: @project, nestLevel: 1, title: 'Group 1')
    upleaf = FactoryGirl.create(:leaf, project: @project, parentID: @testgroup.id.to_s, nestLevel: 1,
                                 conjoined_to: create(:leaf, project: @project, parentID: @testgroup.id.to_s, nestLevel: 1).id.to_s)
    @upleafs = [upleaf, Leaf.find(upleaf.conjoined_to)]
    @testmidgroup = FactoryGirl.create(:group, project: @project, parentID: @testgroup.id.to_s, nestLevel: 2, title: 'Group 2')
    @midleafs = 2.times.collect { FactoryGirl.create(:leaf, project: @project, parentID: @testmidgroup.id.to_s, nestLevel: 2) }
    @botleafs = 2.times.collect { FactoryGirl.create(:leaf, project: @project, parentID: @testgroup.id.to_s, nestLevel: 1) }
    @botleafs[1].update(type: 'Endleaf', attached_above: 'sewn')
    @project.add_groupIDs([@testgroup.id.to_s, @testmidgroup.id.to_s], 0)
    @testgroup.add_members([@upleafs[0].id.to_s, @upleafs[1].id.to_s, @testmidgroup.id.to_s, @botleafs[0].id.to_s, @botleafs[1].id.to_s], 0)
    @testmidgroup.add_members([@midleafs[0].id.to_s, @midleafs[1].id.to_s], 0)
    @testterm = FactoryGirl.create(:term, project: @project,
                                   attachments: [@testgroup,
                                                 @botleafs[0],
                                                 Side.find(@botleafs[0].rectoID),
                                                 Side.find(@botleafs[0].versoID)],
                                   title: 'Iron-gall', taxonomy: 'Ink', description: 'This is a test', uri: 'https://www.test.com/', show: true)
    @project.reload
  end


  context 'when exporting JSON' do
  it 'builds the right JSON' do
    result = buildJSON(@project)
    expect(result[:project]).to eq({
      title: 'Sample project',
      shelfmark: 'Ravenna 384.2339',
      notationStyle: 'r-v',
      metadata: { 'date' => '18th century' },
      preferences: { 'showTips' => true },
      manifests: { '12341234' => { 'id' => '12341234', 'url' => 'https://digital.library.villanova.edu/Item/vudl:99213/Manifest', 'name' => 'Boston, and Bunker Hill.' } },
      taxonomies: ['Ink', 'Unknown']
    })
    expect(result[:groups]).to eq({
      1 => {:params=>{:type=>"Quire", :title=>"Group 1", :nestLevel=>1}, :tacketed=>[], :sewing=>[], :parentOrder=>nil, :memberOrders=>["Leaf_1", "Leaf_2", "Group_2", "Leaf_5", "Leaf_6"]},
      2 => {:params=>{:type=>"Quire", :title=>"Group 2", :nestLevel=>2}, :tacketed=>[], :sewing=>[], :parentOrder=>1, :memberOrders=>["Leaf_3", "Leaf_4"]}
    })
    expect(result[:leafs]).to eq({
      1 => {:params=>{:folio_number=>"", :material=>"Paper", :type=>"Original", :attached_above=>"None", :attached_below=>"None", :stub=>"No", :nestLevel=>1}, :conjoined_leaf_order=>2, :parentOrder=>1, :rectoOrder=>1, :versoOrder=>1},
      2 => {:params=>{:folio_number=>"", :material=>"Paper", :type=>"Original", :attached_above=>"None", :attached_below=>"None", :stub=>"No", :nestLevel=>1}, :conjoined_leaf_order=>1, :parentOrder=>1, :rectoOrder=>2, :versoOrder=>2},
      3 => {:params=>{:folio_number=>"", :material=>"Paper", :type=>"Original", :attached_above=>"None", :attached_below=>"None", :stub=>"No", :nestLevel=>2}, :conjoined_leaf_order=>nil, :parentOrder=>2, :rectoOrder=>3, :versoOrder=>3},
      4 => {:params=>{:folio_number=>"", :material=>"Paper", :type=>"Original", :attached_above=>"None", :attached_below=>"None", :stub=>"No", :nestLevel=>2}, :conjoined_leaf_order=>nil, :parentOrder=>2, :rectoOrder=>4, :versoOrder=>4},
      5 => {:params=>{:folio_number=>"", :material=>"Paper", :type=>"Original", :attached_above=>"None", :attached_below=>"None", :stub=>"No", :nestLevel=>1}, :conjoined_leaf_order=>nil, :parentOrder=>1, :rectoOrder=>5, :versoOrder=>5},
      6 => {:params=>{:folio_number=>"", :material=>"Paper", :type=>"Endleaf", :attached_above=>"sewn", :attached_below=>"None", :stub=>"No", :nestLevel=>1}, :conjoined_leaf_order=>nil, :parentOrder=>1, :rectoOrder=>6, :versoOrder=>6}
    })
    expect(result[:rectos]).to eq({
      1 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>1},
      2 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>2},
      3 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>3},
      4 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>4},
      5 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>5},
      6 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>6}
    })
    expect(result[:versos]).to eq({
      1 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>1},
      2 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>2},
      3 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>3},
      4 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>4},
      5 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>5},
      6 => {:params=>{:page_number=>"", :texture=>"None", :image=>{}, :script_direction=>"None"}, :parentOrder=>6}
    })
    expect(result[:terms]).to eq({
      1 => {:params=>{:title=>'Iron-gall', :taxonomy=>'Ink', :description=>'This is a test', :uri=>'https://www.test.com/', :show=>true}, :objects=>{:Group=>[1], :Leaf=>[5], :Recto=>[5], :Verso=>[5]}}
    })
  end
  end

  context 'when exporting XML' do
    let(:result) { Nokogiri::XML(buildDotModel(@project)) }

    it 'includes the title' do
      expect(result.css('textblock title').text).to eq 'Sample project'
    end

    it 'includes the shelfmark' do
      expect(result.css('textblock shelfmark').text).to eq 'Ravenna 384.2339'
    end

    it 'includes the date' do
      expect(result.css('textblock date').text).to eq '18th century'
    end

    it 'includes the default sides taxonomy' do
      expect(result.css("taxonomy[xml|id='id-sides'] > label").text).to eq 'Parchment Sides'
    end

    it 'includes the default sides taxonomy terms' do
      sides_term_elements = result.css("taxonomy[xml|id='id-sides'] > term")
      expect(
        sides_term_elements.map { |term| [term['xml:id'], term.at_css('label').text.strip] }
      ).to contain_exactly(%w[id-hs hairside], %w[id-fs fleshside], %w[id-left left], %w[id-right right])
    end

    it 'includes a taxonomy with all terms' do
      expect(result.css("taxonomy[xml|id='id-terms'] > label").text).to eq 'List of all Terms'
    end

    it 'includes all terms in the catch-all taxonomy' do
      term_elements = result.css("taxonomy[xml|id='id-terms'] > term")
      expect(
        term_elements.map { |term| [term['xml:id'], term.at_css('label').text.strip] }
      ).to contain_exactly([@testterm.id, 'Iron-gall'])
    end

    it 'includes the added taxonomy' do
      id = "id-#{Digest::MD5.hexdigest('Ink')}"
      expect(result.css("taxonomy[xml|id=#{id}] > label").text.strip).to eq 'Ink'
    end

    it 'includes the added taxonomy\'s terms' do
      id = "id-#{Digest::MD5.hexdigest('Ink')}"
      expect(
        result.css("taxonomy[xml|id=#{id}] term").map { |term| [term['xml:id'], term.text.strip] }
      ).to contain_exactly([@testterm.id, 'Iron-gall'])
    end

    it 'includes the quires' do
      expect(result.css('quires quire').size).to eq 1
    end

    it 'identifies the group that comprises the quire' do
      expect(result.css('quires quire').first.attribute('id').value).to eq @testgroup.id
    end

    it 'includes the leaves' do
      expect(result.css('leaves leaf').size).to eq [@upleafs, @midleafs, @botleafs].sum(&:size)
    end

    it 'includes conjoin elements for conjoined leaves' do
      expect(result.css('leaf q conjoin').size).to eq 2
    end

    it 'it correctly targets the conjoined leaf' do
      expect(result.css("leaf[xml|id='#{@upleafs.first.id}'] q conjoin[target='##{@upleafs.last.id}']")).to be_present
      expect(result.css("leaf[xml|id='#{@upleafs.last.id}'] q conjoin[target='##{@upleafs.first.id}']")).to be_present
    end

    it 'targets the expected group for a leaf' do
      testgroup_leaf_ids = (@upleafs + @botleafs).map(&:id)
      testgroup_leaf_ids.each do |leaf_id|
        expect(result.css("leaves leaf[xml|id='#{leaf_id}'] q[target='##{@testgroup.id}']")).to be_present
      end
    end

    it 'targets the expected nested group for a leaf' do
      testmidgroup_leaf_ids = @midleafs.map(&:id)
      testmidgroup_leaf_ids.each do |leaf_id|
        expect(result.css("leaves leaf[xml|id='#{leaf_id}'] q[target='##{@testmidgroup.id}']")).to be_present
      end
    end

    it 'includes attachment method with the expected target' do
      expect(result.css("leaves leaf[xml|id='#{@botleafs.last.id}'] attachment-method[target='##{@botleafs.first.id}']" )).to be_present
    end

    it 'includes the mappings' do
      ns = {n: 'http://viscoll.org/schema/collation/'}
      expect(result.xpath("//n:mapping/n:map[@side='right']/@target", ns).text.split.size).to eq(1)
      expect(result.xpath("//n:mapping/n:map[@side='left']/@target", ns).text.split.size).to eq(1)
    end

    it 'targets either group or leaf in the mapping' do
      ns = {n: 'http://viscoll.org/schema/collation/'}
      map_targets = result.xpath("//n:mapping/n:map[@target]/@target", ns)
      map_targets.each do |t|
        expect(t).to match /^#(Leaf|Group)/
      end
    end
  end
end
