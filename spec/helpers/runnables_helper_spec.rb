require 'spec_helper'

include ApplicationHelper
describe RunnablesHelper do
  before :each do
    @anonymous_user = mock_model(User, :roles => ["guest"], :anonymous? => true, :name => "guest")
    @anonymous_user.stub!(:extra_params).and_return({})
    helper.stub!(:current_user).and_return(@anonymous_user)
    helper.stub!(:authenticate_with_http_basic).and_return nil
    @page = mock_model(Page, :name => "Foo")
  end

  describe ".run_button_for" do
    it "should render a run button for a specified page" do
      helper.run_button_for(@page).should == "<a href=\"http://test.host/pages/1002.jnlp\" class=\"run_link rollover\" title=\"Run the Page: 'Foo' as a Java Web Start application. The first time you do this it may take a while to startup as the Java code is downloaded and saved on your hard drive.\"><img alt=\"Run the Page: 'Foo' as a Java Web Start application. The first time you do this it may take a while to startup as the Java code is downloaded and saved on your hard drive.\" src=\"/images/run.png?1295966927\" /></a>"
    end
  end

  describe ".preview_button_for" do
    it "should do something" do
      helper.preview_button_for(@page).should == "<a href=\"http://test.host/pages/1004.jnlp\" class=\"run_link rollover\" title=\"Preview the Page: 'Foo' as a Java Web Start application. The first time you do this it may take a while to startup as the Java code is downloaded and saved on your hard drive.\"><img alt=\"Preview the Page: 'Foo' as a Java Web Start application. The first time you do this it may take a while to startup as the Java code is downloaded and saved on your hard drive.\" src=\"/images/preview.png?1295966927\" /></a>"
    end
  end
end
