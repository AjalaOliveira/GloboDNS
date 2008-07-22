require File.dirname(__FILE__) + '/../spec_helper'

include AuthenticatedTestHelper

describe ZonesController, "index" do
  fixtures :all
  
  it "should display all zones to the admin" do
    login_as(:admin)
    
    get 'index'
    
    response.should render_template('zones/index')
    assigns[:zones].should_not be_empty
    assigns[:zones].size.should be(2)
  end
  
  it "should restrict zones for owners" do
    login_as( :quentin )
    
    get 'index'
    
    response.should render_template('zones/index')
    assigns[:zones].should_not be_empty
    assigns[:zones].size.should be(1)
  end
end

describe ZonesController, "when creating" do
  fixtures :all
  
  before(:each) do
    login_as(:admin)
  end
  
  it "should have a form for adding a new zone" do
    get 'new'
    
    response.should render_template('zones/new')
    assigns[:zone].should be_a_kind_of( Zone )
    assigns[:zone_templates].should_not be_empty
    assigns[:zone_templates].size.should be(3)
  end
  
  it "should not save a partial form" do
    post 'create', :zone => { :name => 'example.org' }, :zone_template => { :id => "" }
    
    response.should_not be_redirect
    response.should render_template('zones/new')
    assigns[:zone_templates].should_not be_empty
  end
  
  it "should build from a zone template if selected" do
    @zone_template = zone_templates(:east_coast_dc)
    ZoneTemplate.stubs(:find).with('1').returns(@zone_template)
    
    post 'create', :zone => { :name => 'example.org', :zone_template_id => "1" }
    
    assigns[:zone].should_not be_nil
    response.should be_redirect
    response.should redirect_to( zone_path(assigns[:zone]) )
  end
  
  it "should be redirected to the zone details after a successful save" do
    post 'create', :zone => { 
      :name => 'example.org', :primary_ns => 'ns1.example.org', 
      :contact => 'admin.example.org', :refresh => 10800, :retry => 7200,
      :expire => 604800, :minimum => 10800, :zone_template_id => "" }
    
    response.should be_redirect
    response.should redirect_to( zone_path( assigns[:zone] ) )
    flash[:info].should_not be_nil
  end
  
  it "should offer to create templates if none are found" do
    pending "Move to view specs"
  end
  
end

describe ZonesController, "should handle a REST client" do
  fixtures :all
  
  before(:each) do
    authorize_as(:api_client)
  end
  
  it "creating a new zone without a template" do
    lambda {
      post 'create', :zone => { 
        :name => 'example.org', :primary_ns => 'ns1.example.org', 
        :contact => 'admin.example.org', :refresh => 10800, :retry => 7200,
        :expire => 604800, :minimum => 10800
      }, :format => "xml"
    }.should change( Zone, :count ).by( 1 )
    
    response.should have_tag( 'zone' )
  end
  
  it "creating a zone with a template" do
    post 'create', :zone => { :name => 'example.org', 
      :zone_template_id => zone_templates(:east_coast_dc).id }, 
      :format => "xml"
    
    response.should have_tag( 'zone' )
  end
  
  it "creating a zone with a named template" do
    post 'create', :zone => { :name => 'example.org', 
      :zone_template_name => zone_templates(:east_coast_dc).name }, 
      :format => "xml"
    
    response.should have_tag( 'zone' )
  end
  
  it "creating a zone with invalid input" do
    lambda {
      post 'create', :zone => {
        :name => 'example.org'
      }, :format => "xml"
    }.should_not change( Zone, :count )
    
    response.should have_tag( 'errors' )
  end
end