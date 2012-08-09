class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  NO_EMAIL_STRING='no-email-'
  # Setup accessible (or protected) attributes for your model
  attr_accessible :login,:email, :password, :password_confirmation, :remember_me
  # attr_accessible :title, :body
  has_many :investigations
  has_many :resource_pages
  has_many :activities
  has_many :sections
  has_many :pages
  has_many :external_activities
  has_many :security_questions

  has_many :data_collectors, :class_name => 'Embeddable::DataCollector'
  has_many :xhtmls, :class_name => 'Embeddable::Xhtml'
  has_many :open_responses, :class_name => 'Embeddable::OpenResponse'
  has_many :multiple_choices, :class_name => 'Embeddable::MultipleChoice'
  has_many :data_tables, :class_name => 'Embeddable::DataTable'
  has_many :drawing_tools, :class_name => 'Embeddable::DrawingTool'
  has_many :mw_modeler_pages, :class_name => 'Embeddable::MwModelerPage'
  has_many :n_logo_models, :class_name => 'Embeddable::NLogoModel'
 
  scope :active, { :conditions => { :state => 'active' } }
  scope :no_email, { :conditions => "email LIKE '#{NO_EMAIL_STRING}%'" }
  scope :email, { :conditions => "email NOT LIKE '#{NO_EMAIL_STRING}%'" }
  scope :default, { :conditions => { :default_user => true } }
  scope :with_role, lambda { | role_name |
    { :include => :roles, :conditions => ['roles.title = ?',role_name]}
  }
  has_settings

  #load it later
  @@anonymous_user = nil
  validates_presence_of     :vendor_interface_id

  has_and_belongs_to_many :roles, :uniq => true, :join_table => "roles_users"
  
  # has_many :resource_pages

  has_one :portal_teacher, :class_name => "Portal::Teacher"
  has_one :portal_student, :class_name => "Portal::Student"

  belongs_to :vendor_interface, :class_name => 'Probe::VendorInterface'
  
  scope :default, { :conditions => { :default_user => true } }
  attr_accessor :skip_notifications

  attr_accessor :updating_password

  acts_as_replicatable

  self.extend SearchableModel
  @@searchable_attributes = %w{login first_name last_name email}

    
   class <<self
    def searchable_attributes
      @@searchable_attributes
    end

    def login_exists?(login)
      User.count(:conditions => "`login` = '#{login}'") >= 1
    end

    def login_does_not_exist?(login)
      User.count(:conditions => "`login` = '#{login}'") == 0
    end

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

  def removed_investigation
    unless self.has_investigations?
      self.remove_role('author')
    end
  end

  def has_investigations?
    investigations.length > 0
  end
# default users are a class of users that can be enable
  default_value_for :default_user, false

  # we need a default Probe::VendorInterface, 6 = Vernier Go! IO
  default_value_for :vendor_interface_id, 14

  attr_accessible :first_name, :last_name, :vendor_interface_id, :external_id
 

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

# a bit of a silly method to help the code in lib/changeable.rb so
  # it doesn't have to special-case findingthe owner of a user object
  def user
    self
  end

  # If this user is a student, allow the student's teacher(s) to make
  # changes to this.
  def is_user?(user)
    if user == self
      true
    elsif user.portal_teacher && self.portal_student && self.portal_student.has_teacher?(user.portal_teacher)
      true
    else
      false
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

  # This method gets a bang because it saves the new questions. -- Cantina-CMH 6/17/10
  def update_security_questions!(new_questions)
    return unless new_questions.is_a?(Array)

    self.security_questions.destroy_all

    new_questions.each do |q|
      self.security_questions << q
      q.save
    end
  end

  def changeable?(user)
    # the Anonymous user can't change anything, always return false
    if(user.anonymous?)
      return false

    # admin and manager users can change everything the system delivers to them
    elsif user.has_role?("admin", "manager")
      true

    # Some things (eg: portal_clazes) might havemultiple owners (users)
    # So provide alternate "is_user?" pattern for those cases.
    # is_user? should take precedence, because "user" is more ambiguous
    # in the case of models with multiple owners
    elsif self.respond_to?(:is_user?)
      if self.is_user?(user)
        true
      else
        false
      end

    # is this object a User object?
    # if so a normal User can only change their own User object
    elsif self.respond_to?(:user)
      if self.user == user
        true
      else
        false
      end

    # if this object is owned and the user is the owner return true
    elsif owned?
      self.user == user

    # else return false
    else
      false
    end
  end

  def owned?
    if self.respond_to? :user
      if self.user.nil?
        return false
      end
      if self.user.anonymous?
        return false
      end
      true
    else
      false
    end
  end

  def un_owned?
    return (! self.owned?)
  end
  #-------
end
