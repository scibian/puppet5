require 'spec_helper'

describe Puppet::Type.type(:service).provider(:debian) do
  if Puppet.features.microsoft_windows?
    # Get a pid for $CHILD_STATUS to latch on to
    command = "cmd.exe /c \"exit 0\""
    Puppet::Util::Execution.execute(command, {:failonfail => false})
  end

  before(:each) do
    # Create a mock resource
    @resource = stub 'resource'

    @provider = subject()

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name, source and path
    @resource.stubs(:[]).with(:name).returns "myservice"
    @resource.stubs(:[]).with(:ensure).returns :enabled
    @resource.stubs(:ref).returns "Service[myservice]"

    @provider.resource = @resource

    @provider.stubs(:command).with(:update_rc).returns "update_rc"
    @provider.stubs(:command).with(:invoke_rc).returns "invoke_rc"
    @provider.stubs(:command).with(:service).returns "service"

    @provider.stubs(:update_rc)
    @provider.stubs(:invoke_rc)
  end

  ['1','2'].each do |version|
    it "should be the default provider on CumulusLinux #{version}" do
      Facter.expects(:value).with(:operatingsystem).at_least_once.returns('CumulusLinux')
      Facter.expects(:value).with(:operatingsystemmajrelease).returns(version)
      expect(described_class.default?).to be_truthy
    end
  end

  it "should be the default provider on Debian" do
    Facter.expects(:value).with(:operatingsystem).at_least_once.returns('Debian')
    Facter.expects(:value).with(:operatingsystemmajrelease).returns('7')
    expect(described_class.default?).to be_truthy
  end

  it "should have an enabled? method" do
    expect(@provider).to respond_to(:enabled?)
  end

  it "should have an enable method" do
    expect(@provider).to respond_to(:enable)
  end

  it "should have a disable method" do
    expect(@provider).to respond_to(:disable)
  end

  context "when enabling" do
    it "should call update-rc.d twice" do
      @provider.expects(:update_rc).twice
      @provider.enable
    end
  end

  context "when disabling" do
    it "should be able to disable services with newer sysv-rc versions" do
      @provider.stubs(:`).with("dpkg --compare-versions $(dpkg-query -W --showformat '${Version}' sysv-rc) ge 2.88 ; echo $?").returns "0"

      @provider.expects(:update_rc).with(@resource[:name], "disable")

      @provider.disable
    end

    it "should be able to enable services with older sysv-rc versions" do
      @provider.stubs(:`).with("dpkg --compare-versions $(dpkg-query -W --showformat '${Version}' sysv-rc) ge 2.88 ; echo $?").returns "1"

      @provider.expects(:update_rc).with("-f", @resource[:name], "remove")
      @provider.expects(:update_rc).with(@resource[:name], "stop", "00", "1", "2", "3", "4", "5", "6", ".")

      @provider.disable
    end
  end

  context "when checking whether it is enabled" do
    it "should call Kernel.system() with the appropriate parameters" do
      @provider.expects(:system).with("/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start").once
      $CHILD_STATUS.stubs(:exitstatus).returns(0)
      @provider.enabled?
    end

    it "should return true when invoke-rc.d exits with 104 status" do
      @provider.stubs(:system)
      $CHILD_STATUS.stubs(:exitstatus).returns(104)
      expect(@provider.enabled?).to eq(:true)
    end

    it "should return true when invoke-rc.d exits with 106 status" do
      @provider.stubs(:system)
      $CHILD_STATUS.stubs(:exitstatus).returns(106)
      expect(@provider.enabled?).to eq(:true)
    end

    shared_examples "manually queries service status" do |status|
      it "links count is 4" do
        @provider.stubs(:system)
        $CHILD_STATUS.stubs(:exitstatus).returns(status)
        @provider.stubs(:get_start_link_count).returns(4)
        expect(@provider.enabled?).to eq(:true)
      end
      it "links count is less than 4" do
        @provider.stubs(:system)
        $CHILD_STATUS.stubs(:exitstatus).returns(status)
        @provider.stubs(:get_start_link_count).returns(3)
        expect(@provider.enabled?).to eq(:false)
      end
    end

    context "when invoke-rc.d exits with 101 status" do
      it_should_behave_like "manually queries service status", 101
    end

    context "when invoke-rc.d exits with 105 status" do
      it_should_behave_like "manually queries service status", 105
    end

    context "when invoke-rc.d exits with 101 status" do
      it_should_behave_like "manually queries service status", 101
    end

    context "when invoke-rc.d exits with 105 status" do
      it_should_behave_like "manually queries service status", 105
    end

    # pick a range of non-[104.106] numbers, strings and booleans to test with.
    [-100, -1, 0, 1, 100, "foo", "", :true, :false].each do |exitstatus|
      it "should return false when invoke-rc.d exits with #{exitstatus} status" do
        @provider.stubs(:system)
        $CHILD_STATUS.stubs(:exitstatus).returns(exitstatus)
        expect(@provider.enabled?).to eq(:false)
      end
    end
  end

  context "when checking service status" do
    it "should use the service command" do
      Facter.stubs(:value).with(:operatingsystem).returns('Debian')
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns('8')
      @resource.stubs(:[]).with(:hasstatus).returns(:true)
      expect(@provider.statuscmd).to eq(["service", @resource[:name], "status"])
    end
  end
end
