# :main: README.md
module Serial
  begin #:nodoc:
    require 'ffi'
  rescue LoadError
    raise LoadError.new 'Could not load ruby gem ffi'
  end

  ##
  # :attr_reader: baud
  # Determine the current serial port baud rate by querying the underlying operating system

  ##
  # :attr_reader: data_bits
  # Determine the current serial port data bits by querying the underlying operating system

  ##
  # :attr_reader: stop_bits
  # Determine the current serial port stop bits by querying the underlying operating system

  ##
  # :attr_reader: parity
  # Determine the current serial port parity by querying the underlying operating system

  ##
  # Create a new Ruby IO configured with the serial port parameters
  #
  # :call-seq:
  #   new(port: '/dev/tty or COM1')
  #   new(port: '/dev/tty or COM1', baud: 9600, data_bits: 8, stop_bits: 1, parity: :none)
  def self.new(config)
    driver = if ('Windows_NT' == ENV['OS'])
      @@loaded_ffi_serial_windows ||= begin
        require 'ffi-serial/windows'
        true
      end
      Windows
    else
      @@loaded_ffi_serial_posix ||= begin
        require 'ffi-serial/posix'
        true
      end
      Posix
    end

    config = config.each_with_object({}) { |(k,v),r| r[k.to_s.strip.chomp.downcase.gsub(/\-|\_|\s/, '')] = v }
    
    port = config.delete('port') { raise ArgumentError.new ':port not specified' }
    baud = config.delete('baud') { 9600 }
    data_bits = config.delete('databits') { 8 }
    stop_bits = config.delete('stopbits') { 1 }
    parity = config.delete('parity') { :none }

    if !config.empty?
      raise ArgumentError.new "Unknown options specified: #{config.keys}"
    end

    # Create a new Ruby IO pointing to the serial port and configure it
    # using the OS specific function
    new_instance = driver.method(:new).call(
      port,
      Integer(baud),
      Integer(data_bits),
      Integer(stop_bits),
      parity.to_s.strip.chomp.downcase.to_sym)

    new_instance
  end
end