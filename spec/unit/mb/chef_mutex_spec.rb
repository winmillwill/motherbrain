require 'spec_helper'

describe MB::ChefMutex do
  subject { chef_mutex }

  let(:chef_mutex) { klass.new(lockset) }

  let(:client_name) { "johndoe" }
  let(:lockset) { { chef_environment: "my_environment" } }

  let(:chef_connection_stub) { stub client_name: client_name }
  let(:locks_stub) { stub(
      delete: true,
      find: nil,
      new: stub(save: true)
  ) }

  before do
    chef_mutex.stub locks: locks_stub
    chef_mutex.stub externally_testing?: false
  end

  its(:type) { should == lockset.keys.first }
  its(:identifier) { should == lockset.values.first }

  its(:name) { should == "#{chef_mutex.type}:#{chef_mutex.identifier}" }
  its(:data_bag_id) { should == "#{chef_mutex.type}-#{chef_mutex.identifier}" }

  describe "#lock" do
    subject(:lock) { chef_mutex.lock }

    it "attempts a lock" do
      chef_mutex.should_receive :attempt_lock

      lock
    end

    context "with no existing lock" do
      before { chef_mutex.stub read: false, write: true }

      it { should be_true }

      context "and the lock attempt fails" do
        before { chef_mutex.stub write: false }

        it { should be_false }
      end
    end

    context "with an existing lock" do
      before { chef_mutex.stub read: {}, write: true }

      it { should be_false }

      context "and force enabled" do
        before do
          chef_mutex.force = true
        end

        it { should be_true }
      end
    end

    context "without a valid lock type" do
      let(:lockset) { { something: "something" } }

      it { -> { lock }.should raise_error MB::InvalidLockType }
    end
  end

  describe "#synchronize" do
    subject(:synchronize) { chef_mutex.synchronize(&test_block) }

    TestProbe = Object.new

    let(:options) { Hash.new }
    let(:test_block) { -> { TestProbe.testing } }

    before do
      chef_mutex.stub lock: true, unlock: true

      TestProbe.stub :testing
    end

    it "runs the block" do
      TestProbe.should_receive :testing

      synchronize
    end

    it "obtains a lock" do
      chef_mutex.should_receive :lock

      synchronize
    end

    it "releases the lock" do
      chef_mutex.should_receive :unlock

      synchronize
    end

    context "when the lock is unobtainable" do
      before do
        chef_mutex.stub lock: false, read: {}
      end

      it "does not attempt to release the lock" do
        chef_mutex.should_not_receive :unlock

        -> { synchronize }.should raise_error MB::ResourceLocked
      end

      it "raises a ResourceLocked error" do
        -> { synchronize }.should raise_error MB::ResourceLocked
      end

      context "and force enabled" do
        before do
          chef_mutex.force = true
        end

        it "locks with force" do
          chef_mutex.should_receive(:lock).and_return(true)

          synchronize
        end
      end
    end

    context "on block failure" do
      before do
        TestProbe.stub(:testing).and_raise(RuntimeError)
      end

      it "raises the error" do
        -> { synchronize }.should raise_error RuntimeError
      end

      it "releases the lock" do
        chef_mutex.should_receive :unlock

        -> { synchronize }.should raise_error RuntimeError
      end

      context "and passed unlock_on_failure: false" do
        before do
          options[:unlock_on_failure] = false
        end

        it "does not release the lock" do
          chef_mutex.should_not_receive :unlock

          -> { synchronize }.should raise_error RuntimeError
        end
      end
    end
  end

  describe "#unlock" do
    subject(:unlock) { chef_mutex.unlock }

    it "attempts an unlock" do
      chef_mutex.should_receive :attempt_unlock

      unlock
    end
  end
end
