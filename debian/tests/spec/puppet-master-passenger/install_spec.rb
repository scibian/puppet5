require 'spec_helper'

describe package('puppet-master-passenger') do
  it { should be_installed }
end

describe package('apache2') do
  it { should be_installed }
end

describe service('apache2') do
  it { should be_enabled }
  it { should be_running }
end

describe port(8140) do
  it { should be_listening.with('tcp6') }
end
