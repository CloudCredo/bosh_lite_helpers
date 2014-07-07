require 'pathname'
require_relative '../../lib/bosh_lite_helpers'

# BOSH Lite Helpers
module BoshLiteHelpers
  describe Api do

    let(:command_runner) { double }

    def output(fixture_name)
      File.read(Pathname.new(__FILE__).dirname + 'fixtures' + fixture_name.to_s)
    end

    before do
      allow(command_runner).to receive(:run).and_return(exit_code: 0)
    end

    subject do
      Object.extend(Api).tap { |api| api.command_runner = command_runner }
    end

    describe '#bosh_lite' do
      it 'targets the standard bosh lite endpoint' do
        expect(command_runner).to receive(:run).with(
          'bosh -n target https://192.168.50.4:25555').and_return(exit_code: 0)
        subject.bosh_lite {}
      end
      it 'logs into the bosh director with the default password' do
        expect(command_runner).to receive(:run).with(
          'bosh -n login admin admin').and_return(exit_code: 0)
        subject.bosh_lite {}
      end
      it 'yields' do
        expect { |b| subject.bosh_lite(&b) }.to yield_control
      end
      context 'when the bosh director is unavailable' do
        it 'raises' do
          expect(command_runner).to receive(:run).with(
            'bosh -n target https://192.168.50.4:25555').and_return(
            exit_code: 1, stdout: '', stderr: output(:director_unavailable))
          expect { subject.bosh_lite {} }.to raise_error(BoshLiteError)
        end
      end
      context 'when the default admin password has been changed' do
        it 'raises' do
          expect(command_runner).to receive(:run).with(
            'bosh -n target https://192.168.50.4:25555').and_return(
            exit_code: 1, stdout: '', stderr: output(:login_failed))
          expect { subject.bosh_lite {} }.to raise_error(BoshLiteError)
        end
      end
    end

    describe '#create_release' do
      it 'creates the release with the force flag' do
        expect(command_runner).to receive(:run).with(
          'bosh -n create release --force').and_return(
          exit_code: 0, stdout: output(:create_release_ok), stderr: '')
        subject.create_release
      end
      context 'when the release directory is invalid' do
        it 'raises' do
          expect(command_runner).to receive(:run).with(
            'bosh -n create release --force').and_return(
            exit_code: 1, stdout: '', stderr: output(:create_release_invalid))
          expect { subject.create_release }.to raise_error(BoshLiteError)
        end
      end
    end

    describe '#delete_release' do
      context 'when the release exists' do
        it 'deletes the release' do
          allow(command_runner).to receive(:run).with(
            'bosh -n releases').and_return(
            exit_code: 0, stdout: output(:release_present), stderr: '')
          expect(command_runner).to receive(:run).with(
            'bosh -n delete release my_release')
          subject.delete_release 'my_release'
        end
      end
      context 'when no releases exist' do
        it 'does not try to delete the release' do
          allow(command_runner).to receive(:run).with(
            'bosh -n releases').and_return(
            exit_code: 1, stdout: '', stderr: output(:no_releases))
          expect(command_runner).not_to receive(:run).with(
            'bosh -n delete release my_release')
          subject.delete_release 'my_release'
        end
      end
      context 'when the release does not exist' do
        it 'does not try to delete the release' do
          allow(command_runner).to receive(:run).with(
            'bosh -n releases').and_return(
            exit_code: 0, stdout: output(:release_not_present), stderr: '')
          expect(command_runner).not_to receive(:run).with(
            'bosh -n delete release my_release')
          subject.delete_release 'my_release'
        end
      end
    end

    describe '#delete_deployment' do
      context 'when the deployment exists' do
        it 'deletes the deployment' do
          allow(command_runner).to receive(:run).with(
            'bosh -n deployments').and_return(
            exit_code: 0, stdout: output(:deployment_present), stderr: '')
          expect(command_runner).to receive(:run).with(
            'bosh -n delete deployment my_deployment')
          subject.delete_deployment 'my_deployment'
        end
      end
      context 'when no deployments exist' do
        it 'does not try to delete the deployment' do
          allow(command_runner).to receive(:run).with(
            'bosh -n deployments').and_return(
            exit_code: 1, stdout: '', stderr: output(:no_deployments))
          expect(command_runner).not_to receive(:run).with(
            'bosh -n delete deployment my_deployment')
          subject.delete_deployment 'my_deployment'
        end
      end
      context 'when the deployment does not exist' do
        it 'does not try to delete the deployment' do
          allow(command_runner).to receive(:run).with(
            'bosh -n deployments').and_return(
            exit_code: 0, stdout: output(:deployment_not_present), stderr: '')
          expect(command_runner).not_to receive(:run).with(
            'bosh -n delete deployment my_deployment')
          subject.delete_deployment 'my_deployment'
        end
      end
    end

    describe '#deploy' do
      it 'sets the deployment to the provided manifest path' do
        expect(command_runner).to receive(:run).with(
            'bosh -n deployment /path/to/manifest.yml').and_return(exit_code: 0)
        subject.deploy '/path/to/manifest.yml'
      end
      it 'performs the deployment' do
        expect(command_runner).to receive(:run).with(
            'bosh -n deploy').and_return(exit_code: 0)
        subject.deploy '/path/to/manifest.yml'
      end
    end

    describe '#upload_release' do
      it 'uploads the release with the rebase flag' do
        expect(command_runner).to receive(:run).with(
          'bosh -n upload release --rebase').and_return(
          exit_code: 0, stdout: output(:upload_release_ok), stderr: '')
        subject.upload_release
      end
      context 'when the release has not changed' do
        it 'does not error' do
          expect(command_runner).to receive(:run).with(
            'bosh -n upload release --rebase').and_return(
            exit_code: 1,
            stdout: output(:upload_release_rebase_error),
            stderr: '')
          subject.upload_release
        end
      end
      context 'when the director errors' do
        it 'raises' do
          expect(command_runner).to receive(:run).with(
            'bosh -n upload release --rebase').and_return(
            exit_code: 1, stdout: '', stderr: 'HTTP 500:')
          expect { subject.upload_release }.to raise_error(BoshLiteError)
        end
      end
    end

    describe '#upload_stemcell' do
      let(:stemcell_path) do
        '/path/to/bosh-stemcell-60-warden-boshlite-ubuntu-lucid-go_agent.tgz'
      end
      let(:stemcell_url) do
        'https://s3.amazonaws.com/bosh-jenkins-artifacts/bosh-stemcell/'\
        'warden/bosh-stemcell-60-warden-boshlite-ubuntu-lucid-go_agent.tgz'
      end
      context 'when the stemcell does not exist' do
        it 'uploads the specified stemcell' do
          expect(command_runner).to receive(:run).with(
            'bosh -n stemcells').and_return(
            exit_code: 0, stdout: output(:stemcell_not_present), stderr: '')
          expect(command_runner).to receive(:run).with(
            "bosh -n upload stemcell #{stemcell_path}").and_return(
            exit_code: 0, stdout: output(:upload_stemcell_ok), stderr: '')
          subject.upload_stemcell(Pathname.new(stemcell_path))
        end
      end
      context 'when no stemcells exist' do
        it 'does not error' do
          expect(command_runner).to receive(:run).with(
            'bosh -n stemcells').and_return(
            exit_code: 1, stdout: '', stderr: output(:no_stemcells))
          subject.upload_stemcell(Pathname.new(stemcell_path))
        end
        it 'uploads the stemcell' do
          expect(command_runner).to receive(:run).with(
            'bosh -n stemcells').and_return(
            exit_code: 1, stdout: '', stderr: output(:no_stemcells))
          expect(command_runner).to receive(:run).with(
            "bosh -n upload stemcell #{stemcell_path}")
          subject.upload_stemcell(Pathname.new(stemcell_path))
        end
      end
      context 'when the stemcell exists and is in use' do
        context 'with a local stemcell path' do
          it 'does not try to upload the stemcell' do
            expect(command_runner).to receive(:run).with(
              'bosh -n stemcells').and_return(
              exit_code: 0, stdout: output(:stemcell_used), stderr: '')
            expect(command_runner).not_to receive(:run).with(
              "bosh -n upload stemcell #{stemcell_path}")
            subject.upload_stemcell(Pathname.new(stemcell_path))
          end
        end
        context 'with a remote stemcell url' do
          it 'does not try to upload the stemcell' do
            expect(command_runner).to receive(:run).with(
              'bosh -n stemcells').and_return(
              exit_code: 0, stdout: output(:stemcell_used), stderr: '')
            expect(command_runner).not_to receive(:run).with(
              "bosh -n upload stemcell #{stemcell_path}")
            subject.upload_stemcell(URI.parse(stemcell_url))
          end
        end
      end
      context 'when the stemcell exists and is not in use' do
        it 'does not try to upload the stemcell' do
          expect(command_runner).to receive(:run).with(
            'bosh -n stemcells').and_return(
            exit_code: 0, stdout: output(:stemcell_unused), stderr: '')
          expect(command_runner).not_to receive(:run).with(
            "bosh -n upload stemcell #{stemcell_path}")
          subject.upload_stemcell(Pathname.new(stemcell_path))
        end
      end
    end

    describe '#with_new_empty_directory' do
      before do
        allow(Dir).to receive(:pwd)
        allow(Dir).to receive(:chdir)
        allow(Dir).to receive(:mktmpdir).and_yield('/tmp/path')
      end
      it 'changes to a new temporary directory' do
        expect(Dir).to receive(:mktmpdir).and_yield('/tmp/path')
        expect(Dir).to receive(:chdir).with('/tmp/path')
        subject.with_new_empty_directory {}
      end
      it 'yields control to the provided block' do
        expect { |b| subject.with_new_empty_directory(&b) }.to yield_control
      end
      it 'restores the old directory after the block' do
        expect(Dir).to receive(:pwd).and_return('/the/original/path')
        expect(Dir).to receive(:chdir).with('/the/original/path')
        subject.with_new_empty_directory {}
      end
      context 'when an error occurs' do
        it 'restores the old directory after the block' do
          expect(Dir).to receive(:pwd).and_return('/the/original/path')
          expect(Dir).to receive(:chdir).with('/the/original/path')
          expect { subject.with_new_empty_directory { fail } }.to raise_error
        end
      end
    end

  end
end
