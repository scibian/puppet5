require 'spec_helper'

PROVIDERS = ["undef", "'debian'"]
SERVICES = ["dep8-sd-sysv", "dep8-sysv-only"]

def set_service(service, running, enable, provider)
  command("puppet apply --debug --detailed-exitcodes -e \"service { '#{service}' : ensure => #{running}, enable => #{enable}, provider => #{provider} }\"") 
end

def get_enabled(service)
  command("sh -c \"ls /etc/rc[2-5].d/S*#{service}\"")
end

describe file("/run/systemd/system") do
  it { should_not exist }
end

PROVIDERS.each do |provider|
  SERVICES.each do |service|
    describe set_service(service, "running", "true", provider) do
      its(:stdout) { should match /update-rc\.d.*enable/ }
      its(:stdout) { should match /service.*start/ }
      its(:exit_status) { should eq 2 }
    end

    describe get_enabled(service) do
      its(:exit_status) { should eq 0 }
    end

    describe file("/tmp/#{service}.status") do
      it { should exist }
    end

    describe set_service(service, "running", "true", provider) do
      its(:exit_status) { should eq 0 }
    end

    describe set_service(service, "stopped", "false", provider) do
      its(:stdout) { should match /update-rc\.d.*disable/ }
      its(:stdout) { should match /service.*stop/ }
      its(:exit_status) { should eq 2 }
    end
    
    describe set_service(service, "stopped", "false", provider) do
      its(:exit_status) { should eq 0 }
    end
    
    describe get_enabled(service) do
      its(:exit_status) { should eq 2 }
    end

    describe file("/tmp/#{service}.status") do
      it { should_not exist }
    end
  end
end
