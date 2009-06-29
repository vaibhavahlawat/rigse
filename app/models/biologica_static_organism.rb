class BiologicaStaticOrganism < ActiveRecord::Base
  
  belongs_to :user
  has_many :page_elements, :as => :embeddable
  has_many :pages, :through =>:page_elements
  has_many :teacher_notes, :as => :authored_entity
  belongs_to :biologica_organism
  
  acts_as_replicatable

  include Changeable
  
  include Cloneable
  @@cloneable_associations = [:biologica_organism]

  self.extend SearchableModel
  
  @@searchable_attributes = %w{name description}
  
  class <<self
    def searchable_attributes
      @@searchable_attributes
    end
    def cloneable_associations
      @@cloneable_associations
    end
  end

  default_value_for :name, "Biologica Static Organism element"
  default_value_for :description, "description ..."

  send_update_events_to :investigations

  def self.display_name
    "Biologica Static Organism View"
  end
  
  def organisms_in_activity_scope(scope)
    if scope && scope.class != BiologicaStaticOrganism
      scope.activity.biologica_organisms - [self]
    else
      []
    end
  end

  def investigations
    invs = []
    self.pages.each do |page|
      inv = page.investigation
      invs << inv if inv
    end
  end

end
