require 'spec_helper'

context Puppet::Type.type(:package).provider(:gem) do
  context 'installing myresource' do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed
      )
    end

    let(:provider) do
      provider = described_class.new
      provider.resource = resource
      provider
    end

    before :each do
      resource.provider = provider
    end

    context "when installing" do
      it "should use the path to the gem" do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
        provider.expects(:execute).with { |args| args[0] == "/my/gem" }.returns ""
        provider.install
      end

      it "should specify that the gem is being installed" do
        provider.expects(:execute).with { |args| args[1] == "install" }.returns ""
        provider.install
      end

      it "should specify that documentation should not be included" do
        provider.expects(:execute).with { |args| args[2] == "--no-rdoc" }.returns ""
        provider.install
      end

      it "should specify that RI should not be included" do
        provider.expects(:execute).with { |args| args[3] == "--no-ri" }.returns ""
        provider.install
      end

      it "should specify the package name" do
        provider.expects(:execute).with { |args| args[4] == "myresource" }.returns ""
        provider.install
      end

      it "should not append install_options by default" do
        provider.expects(:execute).with { |args| args.length == 5 }.returns ""
        provider.install
      end

      it "should allow setting an install_options parameter" do
        resource[:install_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
        provider.expects(:execute).with { |args| args[2] == '--force' && args[3] == '--bindir=/usr/bin' }.returns ''
        provider.install
      end

      context "when a source is specified" do
        context "as a normal file" do
          it "should use the file name instead of the gem name" do
            resource[:source] = "/my/file"
            provider.expects(:execute).with { |args| args[2] == "/my/file" }.returns ""
            provider.install
          end
        end

        context "as a file url" do
          it "should use the file name instead of the gem name" do
            resource[:source] = "file:///my/file"
            provider.expects(:execute).with { |args| args[2] == "/my/file" }.returns ""
            provider.install
          end
        end

        context "as a puppet url" do
          it "should fail" do
            resource[:source] = "puppet://my/file"
            expect { provider.install }.to raise_error(Puppet::Error)
          end
        end

        context "as a non-file and non-puppet url" do
          it "should treat the source as a gem repository" do
            resource[:source] = "http://host/my/file"
            provider.expects(:execute).with { |args| args[2..4] == ["--source", "http://host/my/file", "myresource"] }.returns ""
            provider.install
          end
        end

        context "as a windows path on windows", :if => Puppet.features.microsoft_windows? do
          it "should treat the source as a local path" do
            resource[:source] = "c:/this/is/a/path/to/a/gem.gem"
            provider.expects(:execute).with { |args| args[2] == "c:/this/is/a/path/to/a/gem.gem" }.returns ""
            provider.install
          end
        end

        context "with an invalid uri" do
          it "should fail" do
            URI.expects(:parse).raises(ArgumentError)
            resource[:source] = "http:::::uppet:/:/my/file"
            expect { provider.install }.to raise_error(Puppet::Error)
          end
        end
      end
    end

    context "#latest" do
      it "should return a single value for 'latest'" do
        #gemlist is used for retrieving both local and remote version numbers, and there are cases
        # (particularly local) where it makes sense for it to return an array.  That doesn't make
        # sense for '#latest', though.
        provider.class.expects(:gemlist).with({ :justme => 'myresource'}).returns({
          :name     => 'myresource',
          :ensure   => ["3.0"],
          :provider => :gem,
        })
        expect(provider.latest).to eq("3.0")
      end

      it "should list from the specified source repository" do
        resource[:source] = "http://foo.bar.baz/gems"
        provider.class.expects(:gemlist).
          with({:justme => 'myresource', :source => "http://foo.bar.baz/gems"}).
          returns({
            :name     => 'myresource',
            :ensure   => ["3.0"],
            :provider => :gem,
          })
          expect(provider.latest).to eq("3.0")
      end
    end

    context "#instances" do
      before do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
      end

      it "should return an empty array when no gems installed" do
        described_class.expects(:execute).with(%w{/my/gem list --local}, {:failonfail => true, :combine => true, :custom_environment => {"HOME"=>ENV["HOME"]}}).returns("\n")
        expect(described_class.instances).to eq([])
      end

      it "should return ensure values as an array of installed versions" do
        described_class.expects(:execute).with(%w{/my/gem list --local}, {:failonfail => true, :combine => true, :custom_environment => {"HOME"=>ENV["HOME"]}}).returns <<-HEREDOC.gsub(/        /, '')
        systemu (1.2.0)
        vagrant (0.8.7, 0.6.9)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:ensure => ["1.2.0"],          :provider => :gem, :name => 'systemu'},
          {:ensure => ["0.8.7", "0.6.9"], :provider => :gem, :name => 'vagrant'}
        ])
      end

      it "should ignore platform specifications" do
        described_class.expects(:execute).with(%w{/my/gem list --local}, {:failonfail => true, :combine => true, :custom_environment => {"HOME"=>ENV["HOME"]}}).returns <<-HEREDOC.gsub(/        /, '')
        systemu (1.2.0)
        nokogiri (1.6.1 ruby java x86-mingw32 x86-mswin32-60, 1.4.4.1 x86-mswin32)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:ensure => ["1.2.0"],          :provider => :gem, :name => 'systemu'},
          {:ensure => ["1.6.1", "1.4.4.1"], :provider => :gem, :name => 'nokogiri'}
        ])
      end

      it "should not list 'default: ' text from rubygems''" do
        described_class.expects(:execute).with(%w{/my/gem list --local}, anything).returns <<-HEREDOC.gsub(/        /, '')
        bundler (1.16.1, default: 1.16.0, 1.15.1)
        HEREDOC

        expect(described_class.instances.map {|p| p.properties}).to eq([
          {:name => 'bundler', :ensure => ["1.16.1", "1.16.0", "1.15.1"], :provider => :gem}
        ])
      end

      it "should not fail when an unmatched line is returned" do
        described_class.expects(:execute).with(%w{/my/gem list --local}, {:failonfail => true, :combine => true, :custom_environment => {"HOME"=>ENV["HOME"]}}).
          returns(File.read(my_fixture('line-with-1.8.5-warning')))

        expect(described_class.instances.map {|p| p.properties}).
          to eq([{:provider=>:gem, :ensure=>["0.3.2"], :name=>"columnize"},
                 {:provider=>:gem, :ensure=>["1.1.3"], :name=>"diff-lcs"},
                 {:provider=>:gem, :ensure=>["0.0.1"], :name=>"metaclass"},
                 {:provider=>:gem, :ensure=>["0.10.5"], :name=>"mocha"},
                 {:provider=>:gem, :ensure=>["0.8.7"], :name=>"rake"},
                 {:provider=>:gem, :ensure=>["2.9.0"], :name=>"rspec-core"},
                 {:provider=>:gem, :ensure=>["2.9.1"], :name=>"rspec-expectations"},
                 {:provider=>:gem, :ensure=>["2.9.0"], :name=>"rspec-mocks"},
                 {:provider=>:gem, :ensure=>["0.9.0"], :name=>"rubygems-bundler"},
                 {:provider=>:gem, :ensure=>["1.11.3.3"], :name=>"rvm"}])
      end
    end

    context "listing gems" do
      context "searching for a single package" do
        it "searches for an exact match" do
          described_class.expects(:execute).with(includes('\Abundler\z'), {:failonfail => true, :combine => true, :custom_environment => {"HOME"=>ENV["HOME"]}}).returns(File.read(my_fixture('gem-list-single-package')))
          expected = {:name => 'bundler', :ensure => %w[1.6.2], :provider => :gem}
          expect(described_class.gemlist({:justme => 'bundler'})).to eq(expected)
        end
      end
    end

    context 'insync?' do
      context 'for array of versions' do
        let(:is) { ['1.3.4', '3.6.1', '5.1.2'] }

        it 'returns true for ~> 1.3' do
          resource[:ensure] = '~> 1.3'
          expect(provider).to be_insync(is)
        end

        it 'returns false for ~> 2' do
          resource[:ensure] = '~> 2'
          expect(provider).to_not be_insync(is)
        end

        it 'returns true for > 4' do
          resource[:ensure] = '> 4'
          expect(provider).to be_insync(is)
        end

        it 'returns true for 3.6.1' do
          resource[:ensure] = '3.6.1'
          expect(provider).to be_insync(is)
        end

        it 'returns false for 3.6.2' do
          resource[:ensure] = '3.6.2'
          expect(provider).to_not be_insync(is)
        end
      end

      context 'for string version' do
        let(:is) { '1.3.4' }

        it 'returns true for ~> 1.3' do
          resource[:ensure] = '~> 1.3'
          expect(provider).to be_insync(is)
        end

        it 'returns false for ~> 2' do
          resource[:ensure] = '~> 2'
          expect(provider).to_not be_insync(is)
        end

        it 'returns false for > 4' do
          resource[:ensure] = '> 4'
          expect(provider).to_not be_insync(is)
        end

        it 'returns true for 1.3.4' do
          resource[:ensure] = '1.3.4'
          expect(provider).to be_insync(is)
        end

        it 'returns false for 3.6.1' do
          resource[:ensure] = '3.6.1'
          expect(provider).to_not be_insync(is)
        end
      end

      it 'should return false for bad version specifiers' do
        resource[:ensure] = 'not a valid gem specifier'
        expect(provider).to_not be_insync('1.0')
      end

      it 'should return false for :absent' do
        resource[:ensure] = '~> 1.0'
        expect(provider).to_not be_insync(:absent)
      end
    end
  end

  context 'uninstalling myresource' do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :absent
      )
    end

    let(:provider) do
      provider = described_class.new
      provider.resource = resource
      provider
    end

    before :each do
      resource.provider = provider
    end

    context "when uninstalling" do
      it "should use the path to the gem" do
        described_class.stubs(:command).with(:gemcmd).returns "/my/gem"
        provider.expects(:execute).with { |args| args[0] == "/my/gem" }.returns ""
        provider.uninstall
      end

      it "should specify that the gem is being uninstalled" do
        provider.expects(:execute).with { |args| args[1] == "uninstall" }.returns ""
        provider.uninstall
      end

      it "should specify that the relevant executables should be removed without confirmation" do
        provider.expects(:execute).with { |args| args[2] == "--executables" }.returns ""
        provider.uninstall
      end

      it "should specify that all the matching versions should be removed" do
        provider.expects(:execute).with { |args| args[3] == "--all" }.returns ""
        provider.uninstall
      end

      it "should specify the package name" do
        provider.expects(:execute).with { |args| args[4] == "myresource" }.returns ""
        provider.uninstall
      end

      it "should not append uninstall_options by default" do
        provider.expects(:execute).with { |args| args.length == 5 }.returns ""
        provider.uninstall
      end

      it "should allow setting an uninstall_options parameter" do
        resource[:uninstall_options] = [ '--ignore-dependencies', {'--version' => '0.1.1' } ]
        provider.expects(:execute).with { |args| args[5] == '--ignore-dependencies' && args[6] == '--version=0.1.1' }.returns ''
        provider.uninstall
      end
    end
  end
end
