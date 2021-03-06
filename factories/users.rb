##
## Factories that have to do with setting up accounts.
##

##
## Emails and Logins will be derived from the login sequence
##

Factory.sequence(:login) do |n| 
  "login_#{UUIDTools::UUID.timestamp_create.to_s[0..20]}"
end

##
## Factory for user
##
Factory.define :user do |f|
  f.login    { Factory.next(:login) }
  f.first_name  'joe'
  f.last_name  'user' 
  f.email  { |u| "#{u.login}@concord.org"}
  f.password  'password' 
  f.password_confirmation  {|u| u.password}
  f.skip_notifications true
  f.require_password_reset false
  f.roles  { [ Factory.next(:member_role)] }
  f.confirmed_at '5/5/2009'
  # f.confirmation_sent_at '8/8/2012'
  # f.confirmation_token '23456'
  f.vendor_interface { |d| Probe::VendorInterface.find(:first) || Factory(:probe_vendor_interface) }
end


##
## Singleton Factory Pattern for Admin user.
##
Factory.sequence :admin_user do |n| 
  admin = User.find_by_login('admin') 
  unless admin
    admin = Factory(:user,
    {
      :login => 'admin',
      # :password =>'password',  # all passwords are 'password' (defined in user factory)
      :first_name => 'admin',
      :site_admin => 1,
      :roles => [Factory.next(:member_role),Factory.next(:admin_role)]
    })
    admin.confirm!
    # admin.activate
    admin.save!
  end
  admin
end

##
## Singleton Factory Pattern for Researcher user.
##
Factory.sequence :researcher_user do |n| 
  researcher = User.find_by_login('researcher') 
  unless researcher
    researcher = Factory(:user,
    {
      :login => 'researcher',
      # :password =>'password',  # all passwords are 'password' (defined in user factory)
      :first_name => 'researcher',
      :site_admin => 0,
      :roles => [Factory.next(:member_role),Factory.next(:researcher_role)]
    })
    # researcher.register
    # researcher.activate
    researcher.confirm!
    researcher.save!
  end
  researcher
end

##
## Singleton Factory Pattern for Anonymous user.
##
Factory.sequence :anonymous_user do |n|
  anon = nil
  begin
    anon = User.find_by_login('anonymous')
    unless anon
      anon = Factory(:user,
      {
        :login => 'anonymous',
        :first_name => 'anonymous',
        :roles => [Factory.next(:guest_role)]
      })
      # anon.register
      # anon.activate
      anon.confirm!
      # clear any previous Anonymous user still cached as a class variable in the User class
      User.anonymous(true)
      anon.save!
    end
    anon
  rescue
    nil
  end
end

Factory.next(:anonymous_user)
