class BiologicaOrganismsController < ApplicationController
  # GET /biologica_organisms
  # GET /biologica_organisms.xml
  def index    
    @biologica_organisms = BiologicaOrganism.search(params[:search], params[:page], nil)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @biologica_organisms}
    end
  end

  # GET /biologica_organisms/1
  # GET /biologica_organisms/1.xml
  def show
    @biologica_organism = BiologicaOrganism.find(params[:id])
    if request.xhr?
      render :partial => 'biologica_organism', :locals => { :biologica_organism => @biologica_organism }
    else
      respond_to do |format|
        format.html # show.html.haml
        format.otml { render :layout => "layouts/biologica_organism" } # biologica_organism.otml.haml
        format.jnlp { render :partial => 'shared/show', :locals => { :runnable_object => @biologica_organism } }
        format.xml  { render :biologica_organism => @biologica_organism }
      end
    end
  end

  # GET /biologica_organisms/new
  # GET /biologica_organisms/new.xml
  def new
    @biologica_organism = BiologicaOrganism.new
    if request.xhr?
      render :partial => 'remote_form', :locals => { :biologica_organism => @biologica_organism }
    else
      respond_to do |format|
        format.html # renders new.html.haml
        format.xml  { render :xml => @biologica_organism }
      end
    end
  end

  # GET /biologica_organisms/1/edit
  def edit
    @biologica_organism = BiologicaOrganism.find(params[:id])
    if request.xhr?
      render :partial => 'remote_form', :locals => { :biologica_organism => @biologica_organism }
    else
      respond_to do |format|
        format.html 
        format.xml  { render :xml => @biologica_organism  }
      end
    end
  end
  

  # POST /biologica_organisms
  # POST /biologica_organisms.xml
  def create
    @biologica_organism = BiologicaOrganism.new(params[:biologica_organism])
    cancel = params[:commit] == "Cancel"
    if request.xhr?
      if cancel 
        redirect_to :index
      elsif @biologica_organism.save
        render :partial => 'new', :locals => { :biologica_organism => @biologica_organism }
      else
        render :xml => @biologica_organism.errors, :status => :unprocessable_entity
      end
    else
      respond_to do |format|
        if @biologica_organism.save
          flash[:notice] = 'Biologicaorganism was successfully created.'
          format.html { redirect_to(@biologica_organism) }
          format.xml  { render :xml => @biologica_organism, :status => :created, :location => @biologica_organism }
        else
          format.html { render :action => "new" }
          format.xml  { render :xml => @biologica_organism.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # PUT /biologica_organisms/1
  # PUT /biologica_organisms/1.xml
  def update
    cancel = params[:commit] == "Cancel"
    @biologica_organism = BiologicaOrganism.find(params[:id])
    if request.xhr?
      if cancel || @biologica_organism.update_attributes(params[:biologica_organism])
        render :partial => 'show', :locals => { :biologica_organism => @biologica_organism }
      else
        render :xml => @biologica_organism.errors, :status => :unprocessable_entity
      end
    else
      respond_to do |format|
        if @biologica_organism.update_attributes(params[:biologica_organism])
          flash[:notice] = 'Biologicaorganism was successfully updated.'
          format.html { redirect_to(@biologica_organism) }
          format.xml  { head :ok }
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @biologica_organism.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /biologica_organisms/1
  # DELETE /biologica_organisms/1.xml
  def destroy
    @biologica_organism = BiologicaOrganism.find(params[:id])
    respond_to do |format|
      format.html { redirect_to(biologica_organisms_url) }
      format.xml  { head :ok }
      format.js
    end
    
    # TODO:  We should move this logic into the model!
    @biologica_organism.page_elements.each do |pe|
      pe.destroy
    end
    @biologica_organism.destroy    
  end
end
