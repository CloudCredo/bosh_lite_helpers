require 'pathname'
require 'tmpdir'
require_relative 'command_runner'

# BOSH Lite Helpers
module BoshLiteHelpers
  class BoshLiteError < StandardError; end

  # Include this module in your specs
  module Api
    attr_writer :command_runner

    def bosh_lite
      bosh 'target https://192.168.50.4:25555'
      bosh 'login admin admin'
      yield
    end

    def create_release
      bosh 'create release --force'
    end

    def delete_deployment(name)
      return unless bosh_object_exists?(:deployment, name)
      bosh "delete deployment #{name}"
    end

    def delete_release(name)
      return unless bosh_object_exists?(:release, name)
      bosh "delete release #{name}"
    end

    def deploy(manifest_path)
      bosh "deployment #{manifest_path}"
      bosh 'deploy'
    end

    def upload_release
      ignore_error 'Rebase is attempted without any job or package changes' do
        bosh 'upload release --rebase'
      end
    end

    def upload_stemcell(path)
      stemcell = stemcell_from_path(path)
      return if existing_stemcells.include?(stemcell)
      bosh "upload stemcell #{path}"
    end

    def with_new_empty_directory
      old_dir = Dir.pwd
      begin
        Dir.mktmpdir do |empty_dir|
          Dir.chdir(empty_dir)
          yield
        end
      ensure
        Dir.chdir(old_dir)
      end
    end

    private

    def bosh(command)
      result = command_runner.run "bosh -n #{command}"
      unless result[:exit_code] == 0
        fail BoshLiteError, "#{result[:stderr]}\n#{result[:stdout]}"
      end
      result[:stdout]
    end

    def bosh_object_exists?(type, name)
      ignore_error "No #{type}s" do
        bosh("#{type}s").lines.any? { |line| line.include?(" #{name} ") }
      end
    end

    def command_runner
      @command_runner ||= CommandRunner.new
    end

    def existing_stemcells
      ignore_error 'No stemcells' do
        columns = first_two_columns(bosh('stemcells'))
        stemcells = columns.map do |name, version|
          [name.strip, version.strip.to_i]
        end
        stemcells.reject! { |name, _version| name == 'Name' }
        return stemcell_columns_to_hash(stemcells)
      end
      []
    end

    def extract_path(url)
      return Pathname.new(url.path) if url.respond_to?(:path)
      Pathname.new(url)
    end

    def first_two_columns(output)
      columns = output.lines.map do |line|
        line.split('|')[1..2]
      end
      columns.reject { |s| s.empty? }
    end

    def ignore_error(error_message)
      yield
    rescue BoshLiteError => e
      raise unless e.message.include?(error_message)
    end

    def stemcell_columns_to_hash(columns)
      columns.map do |name, version|
        { name: name, version: version }
      end
    end

    def stemcell_from_path(path)
      bn = extract_path(path).basename.to_s
      {
        name: bn.sub(/stemcell-[0-9]+-/, '').sub('.tgz', ''),
        version: bn.match(/stemcell-([0-9]+)-/)[1].to_i
      }
    end
  end
end
