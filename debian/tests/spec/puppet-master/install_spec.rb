require 'spec_helper'

describe package('puppet-master') do
  it { should be_installed }
end

describe service('puppet-master') do
  it { should be_enabled }
  it { should be_running }
end

describe port(8140) do
  it { should be_listening.with('tcp') }
end

describe command('puppet cert print $(hostname --fqdn)') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match( /X509v3 Subject Alternative Name/) }
end
