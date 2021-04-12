require 'spec_helper'

describe package('puppet') do
  it { should be_installed }
end

describe file('/etc/puppet/puppet.conf') do
  it { should be_file }
end

describe command('puppet apply --configprint confdir') do
  its(:stdout) { should eq "/etc/puppet\n" }
end


describe command('puppet agent --configprint confdir') do
  its(:stdout) { should eq "/etc/puppet\n" }
end

describe command('puppet agent --configprint ssldir') do
  its(:stdout) { should eq "/var/lib/puppet/ssl\n" }
end


describe command('puppet master --configprint confdir') do
  its(:stdout) { should eq "/etc/puppet\n" }
end

describe command('puppet master --configprint cadir') do
  its(:stdout) { should eq "/var/lib/puppet/ssl/ca\n" }
end

describe service('puppet') do
  it { should_not be_enabled }
  it { should_not be_running }
end
