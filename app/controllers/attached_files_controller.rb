class AttachedFilesController < ApplicationController
  before_filter :login_required

  def destroy
    @attached_file = AttachedFile.find(params[:id])
    @attached_file.destroy if @attached_file.changeable?(current_user_or_guest)

    redirect_back_or @attached_file.attachable
  end
end
