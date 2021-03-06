require 'spec_helper'

describe Fission::Action::Snapshot::Creator do
  describe 'create_snapshot' do
    before do
      @vm                      = Fission::VM.new 'foo'
      @conf_file_path          = File.join @vm.path, 'foo.vmx'
      @vmrun_cmd               = Fission.config['vmrun_cmd']
      @conf_file_response_mock = mock 'conf_file_response'
      @snapshots_response_mock = mock 'snapshots'
      @running_response_mock   = mock 'running?'

      @running_response_mock.stub_as_successful true
      @conf_file_response_mock.stub_as_successful @conf_file_path
      @snapshots_response_mock.stub_as_successful []

      @vm.stub(:exists?).and_return(true)
      @vm.stub(:snapshots).and_return(@snapshots_response_mock)
      @vm.stub(:running?).and_return(@running_response_mock)
      @vm.stub(:conf_file).and_return(@conf_file_response_mock)
      @creator = Fission::Action::Snapshot::Creator.new @vm
    end

    it "should return an unsuccessful response if the vm doesn't exist" do
      @vm.stub(:exists?).and_return(false)
      @creator.create_snapshot('snap_1').should be_an_unsuccessful_response 'VM does not exist'
    end

    it 'should return an unsuccessful response if the vm is not running' do
      @running_response_mock.stub_as_successful false

      response = @creator.create_snapshot 'snap_1'
      error_message = 'The VM must be running in order to take a snapshot.'
      response.should be_an_unsuccessful_response error_message
    end

    it 'should return an unsuccessful response if unable to determine if running' do
      @running_response_mock.stub_as_unsuccessful
      @creator.create_snapshot('snap_1').should be_an_unsuccessful_response
    end

    it 'should return an unsuccessful response if unable to figure out the conf file' do
      @conf_file_response_mock.stub_as_unsuccessful
      @creator.create_snapshot('snap_1').should be_an_unsuccessful_response
    end

    it 'should return a response when creating the snapshot' do
      executor_mock = mock 'executor'
      response      = stub
      cmd           = "#{@vmrun_cmd} snapshot "
      cmd           << "#{@conf_file_path.gsub ' ', '\ '} \"bar\" 2>&1"

      executor_mock.should_receive(:execute).and_return(executor_mock)
      Fission::Action::ShellExecutor.should_receive(:new).
                                     with(cmd).
                                     and_return(executor_mock)
      Fission::Response.should_receive(:from_shell_executor).
                        with(executor_mock).
                        and_return(response)

      @creator.create_snapshot('bar').should == response
    end

    it 'should return an unsuccessful response if the snapshot name is a duplicate' do
      @snapshots_response_mock.stub_as_successful ['snap_1']
      response = @creator.create_snapshot 'snap_1'
      response.should be_an_unsuccessful_response "There is already a snapshot named 'snap_1'."
    end

    it 'should return an unsuccessful response if there was a problem listing the existing snapshots' do
      @snapshots_response_mock.stub_as_unsuccessful
      @creator.create_snapshot('snap_1').should be_an_unsuccessful_response
    end

  end

end
