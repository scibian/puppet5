require 'spec_helper'

describe command('puppet resource host puppet ip=127.0.81.40') do
  its(:exit_status) { should eq 0 }
end

describe command('puppet cert generate agent.example.com') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should contain('Signed certificate request for agent.example.com') }
end

describe command('puppet agent --enable') do
  its(:exit_status) { should eq 0 }
end

describe command('puppet agent --test --certname agent.example.com') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should contain('Caching catalog for agent.example.com') }
end
