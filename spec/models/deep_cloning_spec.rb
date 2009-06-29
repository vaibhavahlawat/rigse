require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe DeepCloning do
  before(:each) do
    @world = BiologicaWorld.create!(:name => "world", :description => "world description", :species_path => "org/concord/biologica/worlds/dragon.xml")
    @org = BiologicaOrganism.create!(:name => "organism", :description => "organism description", :sex => 0, :fatal_characteristics => true, :biologica_world => @world)
    @static_org = BiologicaStaticOrganism.create(:name => "static org", :description => "static org description", :biologica_organism => @org)
    @static_org2 = BiologicaStaticOrganism.create(:name => "static org2", :description => "static org2 description", :biologica_organism => @org)
    @page = Page.create!(:name => "Page", :description => "Page description")
    @page2 = Page.create!(:name => "Page2", :description => "Page2 description")
    @section = Section.create!(:name => "Section", :description => "Section description")
    @section.pages << @page
    @section.pages << @page2
    @static_org.pages << @page
    @static_org2.pages << @page2
  end
  
  def compare_equal(obj1, obj2, attrs = [])
    compare(obj1, obj2, true, attrs)
  end
  
  def compare_not_equal(obj1, obj2, attrs = [])
    compare(obj1, obj2, false, attrs)
  end
  
  def compare(obj1, obj2, equal, attrs)
    if attrs.size == 0
      # FIXME Compare all the attributes
    else
      attrs.each do |att|
        if equal
          obj1.send(att).should == obj2.send(att)
        else
          obj1.send(att).should_not == obj2.send(att)
        end
      end
    end
  end

  it "should recursively clone page elements" do
    klone = @page.deep_clone :include => {:page_elements => :embeddable}
    klone.save!
    compare_equal(klone, @page, [:name, :description])
    klone.page_elements.size.should == 1
    klone.page_elements[0].embeddable.class.should == BiologicaStaticOrganism
    compare_equal(klone.page_elements[0].embeddable, @static_org, [:name, :description])
    klone.page_elements[0].embeddable.biologica_organism.should_not == nil
    klone.page_elements[0].embeddable.biologica_organism.class.should == BiologicaOrganism
    compare_equal(klone.page_elements[0].embeddable.biologica_organism, @org, [:name, :description, :sex])
    klone.page_elements[0].embeddable.biologica_organism.biologica_world.should_not == nil
    klone.page_elements[0].embeddable.biologica_organism.biologica_world.class.should == BiologicaWorld
    compare_equal(klone.page_elements[0].embeddable.biologica_organism.biologica_world, @world, [:name, :description, :species_path])
  end
  
  it "should not clone uuid or timestamps" do
    klone = @page.deep_clone :never_clone => [:uuid, :created_at, :updated_at], :include => {:page_elements => :embeddable}
    klone.save!
    compare_not_equal(klone, @page, [:uuid, :created_at, :updated_at])
    compare_not_equal(klone.page_elements[0].embeddable, @static_org, [:uuid, :created_at, :updated_at])
    compare_not_equal(klone.page_elements[0].embeddable.biologica_organism, @org, [:uuid, :created_at, :updated_at])
    compare_not_equal(klone.page_elements[0].embeddable.biologica_organism.biologica_world, @world, [:uuid, :created_at, :updated_at])
  end
  
  it "should not make multiple organisms or worlds" do
    klone = @section.deep_clone :no_duplicates => true, :never_clone => [:uuid, :created_at, :updated_at], :include => {:pages => {:page_elements => :embeddable}}
    klone.pages.size.should == 2
    klone.pages[0].page_elements[0].embeddable.biologica_organism.should == klone.pages[1].page_elements[0].embeddable.biologica_organism
    klone.pages[0].page_elements[0].embeddable.biologica_organism.biologica_world.should == klone.pages[1].page_elements[0].embeddable.biologica_organism.biologica_world
  end
  
  it "should make multiple organisms or worlds" do
    klone = @section.deep_clone :no_duplicates => false, :never_clone => [:uuid, :created_at, :updated_at], :include => {:pages => {:page_elements => :embeddable}}
    klone.pages.size.should == 2
    klone.pages[0].page_elements[0].embeddable.biologica_organism.should_not == klone.pages[1].page_elements[0].embeddable.biologica_organism
    klone.pages[0].page_elements[0].embeddable.biologica_organism.biologica_world.should_not == klone.pages[1].page_elements[0].embeddable.biologica_organism.biologica_world
  end

end
