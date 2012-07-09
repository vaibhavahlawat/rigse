module RestrictedPortalController
  # restrict access to sensitive routes to manager 
  def self.included(clazz)
    # include methods like require_roles
    include RestrictedController
     clazz.class_eval {
       before_filter :manager, :only => :index

       protected  
       # must define current_clazz in calling controller class
       def teacher_admin_or_config
         redirect_home unless current_clazz.is_teacher?(current_user_or_guest) || current_user_or_guest.has_role?('admin') || request.format == :config
       end

       def student_teacher_admin_or_config
         redirect_home unless current_clazz.is_student?(current_user_or_guest) || current_clazz.is_teacher?(current_user_or_guest) ||
                   current_user_or_guest.has_role?('admin') || request.format == :config
       end
     }
   end
end
