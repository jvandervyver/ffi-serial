module FFISerial #:nodoc:
  module Posix #:nodoc:
    # Values generated using a FreeBSD 10 instance on EC2

    module LIBC #:nodoc:
      require 'ffi'

      def self.os_specific_constants #:nodoc:
        { 'BAUD' => {
            0 => 0, 50 => 50, 75 => 75, 110 => 110, 134 => 134, 150 => 150, 200 => 200, 300 => 300,
            600 => 600, 1200 => 1200, 1800 => 1800, 2400 => 2400, 4800 => 4800, 7200 => 7200,
            9600 => 9600, 14400 => 14400, 19200 => 19200, 28800 => 28800, 38400 => 38400,
            57600 => 57600, 76800 => 76800, 115200 => 115200, 230400 => 230400,
            460800 => 460800, 921600 => 921600 }.freeze,

          'DATA_BITS' => { 5 => 0, 6 => 256, 7 => 512, 8 => 768 }.freeze,

          'STOP_BITS' => { 1 => 0, 2 => 1024 }.freeze,

          'PARITY' => { :none => 0, :even => 4096, :odd => 12288 }.freeze,

          'IXON' => 512, 'IXOFF' => 1024, 'IXANY' => 2048, 'IGNPAR' => 4, 'CREAD' => 2048, 'CLOCAL' => 32768,
          'HUPCL' => 16384, 'VMIN' => 16, 'VTIME' => 17, 'TCSANOW' => 0, 'F_GETFL' => 3, 'F_SETFL' => 4, }
      end

      class Termios < FFI::Struct #:nodoc:
        layout  :c_iflag, :ulong,
                :c_oflag, :ulong,
                :c_cflag, :ulong,
                :c_lflag, :ulong,
                :cc_c, [:uchar, 20],
                :c_ispeed, :ulong,
                :c_ospeed, :ulong

        def baud #:nodoc:
          CONSTANTS['BAUD_'].fetch(self[:c_ispeed])
        end

        def baud=(val) #:nodoc:
          mask = CONSTANTS['BAUD'].fetch(val, nil)
          if mask.nil?
            raise ArgumentError.new "Invalid baud, supported values #{CONSTANTS['BAUD'].keys.inspect}"
          end
          self[:c_cflag] = self[:c_cflag] | mask; self[:c_ispeed] = mask; self[:c_ospeed] = mask; val
        end
      end
    end
  end
end