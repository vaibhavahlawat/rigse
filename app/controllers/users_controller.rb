class UsersController < ApplicationController
	def preferences
    @user = User.find(params[:id])
    @roles = Role.all
    unless @user.changeable?(current_user)
      flash[:warning]  = "You need to be logged in first."
      redirect_to login_url
    end
  end

  def interface
    # Select the probeware vendor and interface to use when generating jnlps and otml
    # files. This redult is saved in a session variable and if the user is logged-in
    # the selection is also saved into their user record.
    # The result is expressed not only in the jnlp and otml files which are
    # downloaded to the users computer but the vendor_interface id (vid) which is
    # also included in the contruction of the url
    @user = User.find(params[:id])
    if request.xhr?
      render :partial => 'interface', :locals => { :vendor_interface => @user.vendor_interface }
    else
      if !@user.changeable?(current_user_or_guest)
        flash[:warning]  = "You need to be logged in first."
        redirect_to login_url
      else

        if params[:commit] == "Cancel"
          redirect_back_or_default(home_url)
        else
          if request.put?
            respond_to do |format|
              if @user.update_attributes(params[:user])
                format.html {  redirect_back_or_default(home_url) }
                format.xml  { head :ok }
              else
                format.html { render :action => "interface" }
                format.xml  { render :xml => @user.errors.to_xml }
              end
            end
          else
            # @vendor_interface = current_user.vendor_interface
            # @vendor_interfaces = Probe::VendorInterface.all.map { |v| [v.name, v.id] }
            # session[:back_to] = request.env["HTTP_REFERER"]
            # render :action => "interface"
          end
        end
      end
    end
  end

  def vendor_interface
    v_id = params[:vendor_interface]
    if v_id
      @vendor_interface = Probe::VendorInterface.find(v_id)
      render :partial=>'vendor_interface', :layout=>false
    else
      render(:nothing => true)
    end
  end
end