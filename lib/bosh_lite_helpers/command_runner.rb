require 'open3'

module BoshLiteHelpers
  # Wraps running operating system commands
  class CommandRunner
    def run(command, options = {})
      stdout_lines, stderr_lines, status = [], [], nil
      puts command unless options[:quiet]
      Open3.popen3(command) do |_stdin, stdout, stderr, wait_thr|
        read_output(stdout_lines, stdout, options[:quiet])
        read_output(stderr_lines, stderr, options[:quiet])
        status = wait_thr.value
      end
      command_result(status.exitstatus, stdout_lines, stderr_lines)
    end

    def read_output(lines, stream, quiet)
      line = stream.read
      return if line.empty?
      puts line unless quiet
      lines << line
    end

    def command_result(exit_code, stdout_lines, stderr_lines)
      {
        exit_code: exit_code,
        stdout: stdout_lines.join(''),
        stderr: stderr_lines.join('')
      }
    end
  end
end
