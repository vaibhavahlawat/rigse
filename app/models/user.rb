class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :login,:email, :password, :password_confirmation, :remember_me
  # attr_accessible :title, :body

  scope :with_role, lambda { | role_name |
    { :include => :roles, :conditions => ['roles.title = ?',role_name]}
  }
  has_settings

  #load it later
  @@anonymous_user = nil
  validates_presence_of     :vendor_interface_id

  has_and_belongs_to_many :roles, :uniq => true, :join_table => "roles_users"
  
  has_many :resource_pages

  has_one :portal_teacher, :class_name => "Portal::Teacher"
  has_one :portal_student, :class_name => "Portal::Student"
  has_many :investigations

  belongs_to :vendor_interface, :class_name => 'Probe::VendorInterface'
  
  scope :default, { :conditions => { :default_user => true } }
  attr_accessor :skip_notifications

   class <<self
    
    def default_users
      User.find(:all, :conditions => { :default_user => true })
    end

    def suspend_default_users
      default_users.each { |user| user.suspend! if user.state == 'active' }
    end

    def unsuspend_default_users
      default_users.each { |user| user.unsuspend! if user.state == 'suspended' }
    end

    # return the user who is the site administrator
    def site_admin
      User.find_by_email(APP_CONFIG[:default_admin_user][:email])
    end
  end
# default users are a class of users that can be enable
  default_value_for :default_user, false

  # we need a default Probe::VendorInterface, 6 = Vernier Go! IO
  default_value_for :vendor_interface_id, 14

  attr_accessible :first_name, :last_name, :vendor_interface_id
 

  def name
    _fullname = "#{first_name} #{last_name}".strip
    _fullname.empty? ? login : _fullname
  end

  def name_and_login
    _fullname = "#{last_name}, #{first_name}".strip
    _fullname.empty? ? login : "#{_fullname} ( #{login} )"
  end




  def has_role?(*role_list)
    roles.reload # will always hit the database?
    (roles.map{ |r| r.title.downcase } & role_list.flatten).length > 0
  end
  def does_not_have_role?(*role_list)
    !has_role?(role_list)
  end
  def add_role(role)
    unless has_role?(role)
      roles << Role.find_or_create_by_title(role)
    end
  end

  def remove_role(role)
    if has_role?(role)
      roles.delete Role.find_by_title(role)
    end
  end

  def set_role_ids(role_ids)
    all_roles = Role.all
    all_roles.each do |role|
      if role_ids.find { |id| id.to_i == role.id }
        add_role(role.title)
      else
        remove_role(role.title)
      end
    end
  end


  #This funtion overrides the function of devise to allow sign-in using login instead of email.
  def self.find_first_by_auth_conditions(warden_conditions)
      conditions = warden_conditions.dup
      if login = conditions.delete(:login)
        where(conditions).where(["lower(login) = :value OR lower(email) = :value", { :value => login.downcase }]).first
      else
        where(conditions).first
      end
  end


    
   #anonymous user is created if the user is not currently logged in.
  def anonymous?
    self == User.anonymous
  end

  def self.anonymous(reload=false)
    @@anonymous_user = nil if reload
    if @@anonymous_user
      @@anonymous_user
    else
      anonymous_user = User.find_or_create_by_login(
        :login                 => "anonymous",
        #:first_name            => "Anonymous",
        #:last_name             => "User",
        :email                 => "anonymous@concord.org",
        :password              => "password",
        :password_confirmation => "password")
      
      anonymous_user.add_role('guest')
      @@anonymous_user = anonymous_user
    end
  end

  def school
    school_person = self.portal_teacher || self.portal_student
    if (school_person)
      return school_person.school
    end
  end

  def extra_params
    if self.school
      params = school.settings_hash
    end
    if params
      return params.merge(self.settings_hash)
    end
    return self.settings_hash
  end
end
