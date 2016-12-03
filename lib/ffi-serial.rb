module Serial
  begin
    require 'ffi'
  rescue LoadError
    raise LoadError.new 'Could not load ruby gem ffi'
  end

  ##
  # Create a new Ruby IO configured as a Serial Port
  #
  # - Returns: IO (See Ruby standard library for IO)
  def self.new(config = { baud: 9600, data_bits: 8, stop_bits: 1, parity: :none })
    driver = if ('Windows_NT' == ENV['OS'])
      @@loaded_ffi_serial_windows ||= begin
        require 'ffi-serial/windows'
        true
      end
      ::FFISerial::Windows
    else
      @@loaded_ffi_serial_posix ||= begin
        require 'ffi-serial/posix'
        true
      end
      ::FFISerial::Posix
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