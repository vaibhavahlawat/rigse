class MavenJnlp::VersionedJnlp < ActiveRecord::Base
  set_table_name "maven_jnlp_versioned_jnlps"
  
  belongs_to :versioned_jnlp_url, :class_name => "MavenJnlp::VersionedJnlpUrl"
  has_one :maven_jnlp_family, :through => :versioned_jnlp_url, :class_name => "MavenJnlp::VersionedJnlpUrl"

  belongs_to :icon, :class_name => "MavenJnlp::Icon"

  has_and_belongs_to_many :properties, :class_name => "MavenJnlp::Property"
  has_and_belongs_to_many :jars, :class_name => "MavenJnlp::Jar"
  has_and_belongs_to_many :native_libraries, :class_name => "MavenJnlp::NativeLibrary"

  acts_as_replicatable
  
  include Changeable
  
  self.extend SearchableModel
  
  @@searchable_attributes = %w{uuid name codebase href title vendor homepage description}
  
  class <<self
    def searchable_attributes
      @@searchable_attributes
    end
  end
  
  validates_presence_of :versioned_jnlp_url, :message => "association not specified" 
  
  after_create :parse_jnlp_object

  def cache_external_resources
    jnlp_object.cache_resources(jnlp_cache_dir)
    update_jnlp_object
  end

  def jnlp_cache_dir
    File.join(RAILS_ROOT, 'public', 'jnlp')
  end
  
  def require_resources
    @required_resources = jnlp_object.require_resources unless @required_resources
  end
  
  def ot_class_info1(otclass) 
    begin
      java_import otclass 
      name = otclass[/\.([^.]*$)/, 1] 
      puts "fqdn: #{otclass}" 
      puts "name: #{name}" 
      puts 
      ot_klazz = Kernel.const_get(name) 
      ot_klazz.java_class.declared_instance_methods.each do |meth| 
        puts "method name: #{meth.name}" 
        puts "method arity: #{meth.arity}" 
        return_type = meth.return_type 
        if return_type 
          puts "return_type: #{return_type}" 
        else 
          puts "return_type: void" 
        end 
        if meth.arity > 0 
          parameter_types = meth.parameter_types 
          if parameter_types 
            puts "parameter_types: #{parameter_types}" 
          end 
        end 
        puts 
      end
    rescue NameError 
      puts "#{otclass} not found" 
    end 
    puts 
  end

  def ot_class_info2(otclass_str) 
    begin 
      otclass_ruby = eval(otclass_str) 
      otclass = ReflectiveOTClassFactory.singleton.registerClass(otclass_ruby.java_class); 
      ReflectiveOTClassFactory.singleton.processAllNewlyRegisteredClasses(); 
      name = otclass_ruby.java_class.simple_name 
      puts "fqdn: #{otclass_str}" 
      puts "name: #{name}" 
      puts 
      otclass.oTAllClassProperties.each do |prop| 
        puts "prop name: #{prop.name}" 
        type = prop.type 
        if type 
          puts "prop type: #{type.instanceClass.name}" 
        else 
          puts "prop type: void" 
        end 
      end 
    rescue NameError 
      puts "#{otclass_str} not found" 
    end 
    puts 
  end

  def jnlp_object
    @jnlp_object || load_jnlp_object
  end
  
  def load_jnlp_object
    if File.exists?(jnlp_object_path)
      @jnlp_object = YAML.load(File.read(jnlp_object_path))
    else
      update_jnlp_object
    end
  end

  def update_jnlp_object
    @jnlp_object = Jnlp::Jnlp.new(self.versioned_jnlp_url.url)
    @jnlp_object.local_cache_dir = jnlp_cache_dir
    save_jnlp_object
  end

  def save_jnlp_object
    File.open(jnlp_object_path, 'w') do |f|
      f.write YAML.dump(@jnlp_object)
    end
    @jnlp_object
  end
  
  def jnlp_object_path
    File.join(RAILS_ROOT, 'config', 'jnlp_objects', "jnlp_object_#{id}.yaml")
  end

  def parse_jnlp_object
    # jnlp_object = Jnlp::Jnlp.new(jnlp.versioned_jnlp_url.url)    
    self.name                     = jnlp_object.name
    self.main_class               = jnlp_object.main_class
    self.argument                 = jnlp_object.argument
    self.offline_allowed          = jnlp_object.offline_allowed
    self.local_resource_signatures_verified = jnlp_object.local_resource_signatures_verified
    self.include_pack_gzip        = jnlp_object.include_pack_gzip
    self.spec                     = jnlp_object.spec
    self.codebase                 = jnlp_object.codebase
    self.href                     = jnlp_object.href
    self.j2se_version             = jnlp_object.j2se_version
    self.max_heap_size            = jnlp_object.max_heap_size
    self.initial_heap_size        = jnlp_object.initial_heap_size
    self.title                    = jnlp_object.title
    self.vendor                   = jnlp_object.vendor
    self.homepage                 = jnlp_object.homepage
    self.description              = jnlp_object.description

    if icon_object = jnlp_object.icon
      icon = MavenJnlp::Icon.find_or_create_by_href_and_height_and_width(:href => icon_object.href, :height => icon_object.height, :width => icon_object.width)
      self.icon = icon
    end
    
    jnlp_object.jars.each do |jar_object|
      attributes =  MavenJnlp::VersionedJnlp.resource_attributes(jar_object)
      unless jar = MavenJnlp::Jar.find(:first, :conditions => attributes)
        jar = MavenJnlp::Jar.create!(attributes)
      end
      self.jars << jar
    end

    jnlp_object.nativelibs.each do |nativelib_object|
      attributes =  MavenJnlp::VersionedJnlp.resource_attributes(nativelib_object)
      unless native_library = MavenJnlp::NativeLibrary.find(:first, :conditions => attributes)
        native_library = MavenJnlp::NativeLibrary.create!(attributes)
      end
      self.native_libraries << native_library      
    end

    jnlp_object.properties.each do |property_object|
      attributes = {
        :name  => property_object.name,
        :value => property_object.value,
        :os    => property_object.os
      }
      unless property = MavenJnlp::Property.find(:first, :conditions => attributes)
        property = MavenJnlp::Property.create!(attributes)
      end
      self.properties << property
    end
    self.save
  end

  def self.resource_attributes(resource_object)
    { :name               => resource_object.name,
      :main               => resource_object.main,
      :os                 => resource_object.os,
      :href               => resource_object.href,
      :size               => resource_object.size,
      :size_pack_gz       => resource_object.size_pack_gz,
      :signature_verified => resource_object.signature_verified,
      :version_str        => resource_object.version_str }
  end

end
