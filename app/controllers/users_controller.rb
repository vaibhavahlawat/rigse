class UsersController < ApplicationController
	def preferences
    @user = User.find(params[:id])
    @roles = Role.all
    unless @user.changeable?(current_user)
      flash[:warning]  = "You need to be logged in first."
      redirect_to login_url
    end
  end
end