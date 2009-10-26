require 'fileutils'
require 'arrayfields'

class RinetData
  include RinetCsvFields  # definitions for the fields we use when parsing.
  attr_reader :parsed_data
  attr_accessor :logger
  # @@districts = %w{07 16}
  @@districts = %w{07}
  @@csv_files = %w{students staff courses enrollments staff_assignments staff_sakai student_sakai}
  @@local_dir = "#{RAILS_ROOT}/rinet_data/districts/csv"

  @@csv_files.each do |csv_file|
    if csv_file =~/_sakai/
      ## 
      ## Create a Chaching Hash Mapfor sakai login info
      ## for the *_sakai csv files
      ##
      eval <<-END_EVAL
        def #{csv_file}_map
          if @#{csv_file}_map
            return @#{csv_file}_map
          end
          @#{csv_file}_map = {}
          # hash_it
          @parsed_data[:#{csv_file}].each do |auth_tokens|
            @#{csv_file}_map[auth_tokens[0]] = auth_tokens[1]
          end
          return @#{csv_file}_map
        end
      END_EVAL
    end
  end
  
  def initialize
    @rinet_data_config = YAML.load_file("#{RAILS_ROOT}/config/rinet_data.yml")[RAILS_ENV].symbolize_keys

    @students_hash = {}
    # SASID => Portal::Student
    
    @teachers_hash = {}
    # CertID => Portal::Teacher
    
    @course_hash = {}
    # CourseNumber => course
    @clazz_hash = {}
    # Portal::Clazz.id => {:teachers => [], :students => []}

    # we probably want to override this later
    @logger = Rails.logger
  end
  
  
  def get_csv_files
    @new_date_time_key = Time.now.strftime("%Y%m%d_%H%M%S")
    Net::SFTP.start(@rinet_data_config[:host], @rinet_data_config[:username] , :password => @rinet_data_config[:password]) do |sftp|
      @@districts.each do |district|
        local_district_path = "#{@@local_dir}/#{district}/#{@new_date_time_key}"
        FileUtils.mkdir_p(local_district_path)
        @@csv_files.each do |csv_file|
          # download a file or directory from the remote host
          remote_path = "#{district}/#{csv_file}.csv"
          local_path = "#{local_district_path}/#{csv_file}.csv"
          logger.info "downloading: #{remote_path} and saving to: \n  #{local_path}"
          sftp.download!(remote_path, local_path)
        end
        current_path = "#{@@local_dir}/#{district}/current"
        FileUtils.ln_s(local_district_path, current_path, :force => true)
      end
    end
  end

  def parse_csv_files(date_time_key='current')
    if @parsed_data
      @parsed_data # cached data.
    else
      @parsed_data = {}
      @@districts.each do |district|
        parse_csv_files_in_dir("#{@@local_dir}/#{district}/#{date_time_key}",@parsed_data)
      end
    end
    # Data is now available in this format
    # @data['07']['staff'][0][:EmailAddress]
    # lets add login info
    # join_students_sakai
    #  join_staff_sakai
    @parsed_data
  end

  def parse_csv_files_in_dir(local_dir_path,existing_data={})
    @parsed_data = existing_data
    logger.info "working on #{local_dir_path}"
    if File.exists?(local_dir_path)
      
      @@csv_files.each do |csv_file|
        local_path = "#{local_dir_path}/#{csv_file}.csv"
        key = csv_file.to_sym
        @parsed_data[key] = []
        File.open(local_path).each do |line|
          add_csv_row(key,line)
        end
      end
    else
      logger.error "no data folder found: #{local_dir_path}"
    end
  end
  
  def add_csv_row(key,line)
    # if row.respond_to? fields
    FasterCSV.parse(line) do |row|
      if row.class == Array
        row.fields = FIELD_DEFINITIONS[key]
        @parsed_data[key] << row
      else
        logger.warn("couldn't add row data for #{key}: #{line}")
        raise "couldn't add row data for #{key}: #{line}"
      end
    end
  end
  
  
  
  def join_students_sakai 
    @parsed_data[:students].each do |student|
      begin
        student[:login] = student_sakai_map[student[:SASID]]
      rescue
        logger.warn "couldn't map student #{student[:Firstname]} #{student[:Lastname]} (is staff_sakai.csv missing or out of date?)"
        logger.info "ERROR WAS: #{$!}"
      end
    end
  end
  
  def join_staff_sakai
    @parsed_data[:staff].each do |staff_member|
      begin
        staff_member[:login] = staff_sakai_map[staff_member[:TeacherCertNum]]
      rescue 
        logger.warn "couldn't map staff #{staff_member[:Firstname]} #{staff_member[:Lastname]} (is staff_sakai.csv missing or out of date?)"
        logger.info "ERROR WAS: #{$!}"
      end
    end
  end
  
  def school_for(row)
    nces_school = Portal::Nces06School.find(:first, :conditions => {:SEASCH => row[:SchoolNumber]});
    school = nil
    unless nces_school
      logger.warn "could not find school for: #{row[:SchoolNumber]} (have the NCES schools been imported?)"
      logger.info "you might need to run the rake tasks: rake portal:setup:download_nces_data || rake portal:setup:import_nces_from_files"
      # TODO, create one with a special name? Throw exception?
    else
      school = Portal::School.find_or_create_by_nces_school(nces_school)
    end
    school
  end
  
  def district_for(row)
    nces_district = Portal::Nces06District.find(:first, :conditions => {:STID => row[:District]});
    district = nil
    unless nces_district
      logger.warn "could not find distrcit for: #{row[:District]} (have the NCES schools been imported?)"
      logger.info "you might need to run the rake tasks: rake portal:setup:download_nces_data || rake portal:setup:import_nces_from_files"
      # TODO, create one with a special name? Throw exception?
    else
      district = Portal::District.find_or_create_by_nces_district(nces_district)
    end
    district
  end
  

  def create_or_update_user(row)
    # try to cache the data here in memory:
    unless row[:rites_user_id]
      if row[:EmailAddress]
        email = row[:EmailAddress].gsub(/\s+/,"").size > 4 ? row[:EmailAddress].gsub(/\s+/,"") : "#{User::NO_EMAIL_STRING}#{row[:login]}@fakehost.com"
      end
      params = {
        :login  => row[:login] || 'bugusXXXXX',
        :password => row[:Password] || row[:Birthdate],
        :password_confirmation => row[:Password] || row[:Birthdate],
        :first_name => row[:Firstname],
        :last_name  => row[:Lastname],
        :email => email || "no-email@broken.borked" # (otherwise we fail validation)
      }
      user = User.find_or_create_by_login(params)
      user.save!
      row[:rites_user_id]=user.id
      user.unsuspend! if user.state == 'suspended'
      unless user.state == 'active'
        user.register!
        user.activate!
      end
      user.roles.clear
    end
    user
  end
  
  def update_teachers
    new_teachers = @parsed_data[:staff]
    new_teachers.each { |nt| create_or_update_teacher(nt) }
  end
  
  def create_or_update_teacher(row)
    # try and cache our data
    teacher = nil
    unless row[:rites_teacher_id]
      user = create_or_update_user(row)
      teacher = Portal::Teacher.find_or_create_by_user_id(user.id)
      teacher.save!
      row[:rites_user_id]=teacher.id
      # how do we find out the teacher grades?
      # teacher.grades << grade_9
    
      # add the teacher to the school
      school = school_for(row)
      if (school)
        unless school.members.detect { |member| member.login == teacher.login }
          school.members << teacher
        end
      end
      row[:rites_teacher_id] = teacher.id
      if teacher
        @teachers_hash[row[:TeacherCertNum]] = teacher
      end
    else
      logger.info("teacher already defined in rites system")
    end
    teacher
  end
  
  def update_students
    new_teachers = @parsed_data[:students]
    new_teachers.each { |nt| create_or_update_student(nt) }
  end
  
  def create_or_update_student(row)
    student = nil
    unless row[:rites_student_id]
      user = create_or_update_user(row)
      student = user.portal_student
      unless student
        student = Portal::Student.create(:user => user)
        student.save!
        user.portal_student=student;
      end

      # add the student to the school
      school = school_for(row)
      if (school)
        unless school.members.detect { |member| member.login == student.login }
          school.members << student
        end
      end
      row[:rites_student_id] = student.id
      # cache that results in hashtable
      @students_hash[row[:SASID]] = student
    else
      logger.info("student already defined in rites system")
    end
    row
  end
  
  
  def update_courses
    new_courses = @parsed_data[:courses]
    new_courses.each do |nc| 
      create_or_update_course(nc)
    end
  end
  
  def create_or_update_course(row)
    unless row[:rites_course]
      school = school_for(row);
      courses = Portal::Course.find(:all, :conditions => {:name => row[:Title]}).detect { |course| course.school.id == school.id }
      unless courses
        course = Portal::Course.create!( {:name => row[:Title], :school_id => school_for(row).id })
      else
        # TODO: what if we have multiple matches?
        if courses.class == Array
          logger.error("Too many matching courses")
          course = courses[0]
        else
          course = courses
        end
      end
      row[:rites_course] = course
      # cache that results in hashtable
      @course_hash[row[:CourseNumber]] = row[:rites_course]
    else
      logger.info("course already defined in rites system")
    end
    row
  end
  
  
  def update_classes
    # from staff assignments:
    @parsed_data[:staff_assignments].each do |nc| 
      create_or_update_class(nc)
    end
    
    # clear students schedules:
    @students_hash.each_value do |student|
      student.clazzes.delete_all
    end
    
    # and re-enroll
    @parsed_data[:enrollments] .each do |nc| 
      create_or_update_class(nc)
    end

  end
  
  def create_or_update_class(row)
    # use course hashmap to find our course
    portal_course = @course_hash[row[:CourseNumber]]
    unless portal_course && portal_course.class == Portal::Course
      logger.error "course not found #{row[:CourseNumber]} nil: #{portal_course.nil?}"
      return
    end
    
    unless row[:StartDate] && row[:StartDate] =~/\d{4}-\d{2}-\d{2}/
      logger.error "bad start time for class: '#{row[:StartDate]}'" unless row =~/\d{4}-\d{2}-\d{2}/
      return
    end
    
    section = row[:CourseSection]
    start_date = DateTime.parse(row[:StartDate]) 
    clazz = Portal::Clazz.find_or_create_by_course_and_section_and_start_date(portal_course,section,start_date)
    
    if row[:SASID] && @students_hash[row[:SASID]]
      student =  @students_hash[row[:SASID]]
      student.clazzes << clazz
      student.save
    elsif row[:TeacherCertNum] && @teachers_hash[row[:TeacherCertNum]]
      clazz.teacher = @teachers_hash[row[:TeacherCertNum]]
      clazz.save
    else
      logger.error("teacher or student not found: SASID: #{row[:SASID]} cert: #{row[:TeacherCertNum]}")
    end
    row
  end
  
  def join_data
    join_students_sakai
    join_staff_sakai
  end
  
  def update_models
    update_teachers
    update_students
    update_courses
    update_classes
  end
  
  def run_importer(district_directory="#{RAILS_ROOT}/resources/rinet_test_data")
    parse_csv_files_in_dir(district_directory)
    join_data
    update_models
  end
  
end