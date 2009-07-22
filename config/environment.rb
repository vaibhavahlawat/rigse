#b Be sure to restart your server when you modify this file

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.2' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
require File.join(File.dirname(__FILE__), '../vendor/plugins/engines/boot.rb')

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  # See Rails::Configuration for more options.

  # Skip frameworks you're not going to use. To use Rails without a database
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Specify gems that this application depends on. 
  # They can then be installed with "rake gems:install" on new installations.
  # You have to specify the <tt>:lib</tt> option for libraries, where the Gem name (<em>sqlite3-ruby</em>) differs from the file itself (_sqlite3_)
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"

  config.gem "arrayfields"
  config.gem "hpricot", :version => '0.6.164'
  config.gem "capistrano-ext", :lib => "capistrano"
  config.gem 'rubyist-aasm', :lib => 'aasm', :source => 'http://gems.github.com', :version => '>=2.0.2'
  config.gem 'mislav-will_paginate', :version => '2.3.6', :lib => 'will_paginate', :source => 'http://gems.github.com'
  config.gem "haml", :version => '>= 2.2.0'  
  config.gem "RedCloth", :version => '>= 4.1.1'
  config.gem "uuidtools", :version => '>= 2.0.0'
  config.gem "spreadsheet"  #see http://spreadsheet.rubyforge.org/
  config.gem "prawn", :version => '>= 0.4.1'
  config.gem 'mojombo-grit', :lib => 'grit', :source => 'http://gems.github.com', :version => '>=0.9.4'
  config.gem 'open4', :version => '>= 0.9.6'
  config.gem "prawn-format", :lib => 'prawn/format', :version => '>= 0.1.1', :source => 'http://gems.github.com'
  config.gem "chriseppstein-compass", :lib => 'compass', :version => '>= 0.6.3', :source => 'http://gems.github.com'
  config.gem "jnlp", :version => '>= 0.0.5.1'
  config.gem "has_many_polymorphs", :version => ">= 2.13"
  config.gem "ar-extensions", ">= 0.9.1"
  
  # These cause problems with irb. Left in for reference
  # config.gem 'rspec-rails', :lib => 'spec/rails', :version => '1.1.11'
  # config.gem 'rspec', :lib => 'spec', :version => '1.1.11'
  
  # Only load the plugins named here, in the order given. By default, all plugins 
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Make Time.zone default to the specified zone, and make Active Record store time values
  # in the database in UTC, and return them converted to the specified local zone.
  # Run "rake -D time" for a list of tasks for finding time zone names. Comment line to use default local time.
  config.time_zone = 'UTC'

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random, 
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :session_key => '_bort_session',
    :secret      => 'a3e2a51a371bb964a4250c21f8d083f9ddb224d455171dcba55518e74af43366e52e3f239773f90aed0ab6caf6554f051504ce7232599d066150dbabff0f1654'
  }

  # Use the database for sessions instead of the cookie-based default,
  # which shouldn't be used to store highly confidential information
  # (create the session table with "rake db:sessions:create")
  config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # Please note that observers generated using script/generate observer need to have an _observer suffix
  # config.active_record.observers = :user_observer
  
  config.after_initialize do
    opts = config.has_many_polymorphs_options
    opts[:file_pattern] = Array(opts[:file_pattern])
    opts[:file_pattern] << "#{RAILS_ROOT}/vendor/plugins/rites_portal/app/models/**/*.rb"
    config.has_many_polymorphs_options = opts
  end
end

# ANONYMOUS_USER = User.find_by_login('anonymous')

require 'prawn'
require 'prawn/format'

require 'portal_configuration'

# if APP_CONFIG[:enable_default_users]
#   User.unsuspend_default_users
# else
#   User.suspend_default_users
# end

# We have to override the autoload method since the default doesn't handle namespaces well...
module HasManyPolymorphs
  def self.autoload

    _logger_debug "autoload hook invoked"
    
    options[:requirements].each do |requirement|
      _logger_warn "forcing requirement load of #{requirement}"
      require requirement
    end
  
    Dir.glob(options[:file_pattern]).each do |filename|
      next if filename =~ /#{options[:file_exclusions].join("|")}/
      open filename do |file|
        if file.grep(/#{options[:methods].join("|")}/).any?
          begin
            file.rewind
            model = File.basename(filename)[0..-4].camelize
            class_regexp = /class\s+([^\s]+)\s+</
            line = file.grep(class_regexp).first
            if line =~ class_regexp  ## Should match unless no lines were found
              model = $1
            end
            _logger_warn "preloading parent model #{model}"
            model.constantize
          rescue Object => e
            _logger_warn "#{model} could not be preloaded: #{e.inspect}"
          end
        end
      end
    end
  end  
    
end
