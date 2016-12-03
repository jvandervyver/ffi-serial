module Serial #:nodoc:
  module Posix #:nodoc:
    # Values generated using a Raspberry Pi B+ running Raspbian Jesse Lite

    module LIBC #:nodoc:
      require 'ffi'

      def self.os_specific_constants #:nodoc:
        { 'BAUD' => {
          0 => 0, 50 => 1, 75 => 2, 110 => 3, 134 => 4, 150 => 5, 200 => 6, 300 => 7, 600 => 8, 1200 => 9, 1800 => 10, 2400 => 11,
          4800 => 12, 9600 => 13, 19200 => 14, 38400 => 15, 57600 => 4097, 115200 => 4098, 230400 => 4099, 460800 => 4100,
          500000 => 4101, 576000 => 4102, 921600 => 4103, 1000000 => 4104, 1152000 => 4105, 1500000 => 4106, 2000000 => 4107,
          2500000 => 4108, 3000000 => 4109, 3500000 => 4110, 4000000 => 4111 }.freeze,

          'DATA_BITS' => { 5 => 0, 6 => 16, 7 => 32, 8 => 48 }.freeze,

          'STOP_BITS' => { 1 => 0, 2 => 64 }.freeze,

          'PARITY' => { :none => 0, :even => 256, :odd => 768, :space => 1073742080, :mark => 1073742592 }.freeze,

          'IXON' => 1024, 'IXOFF' => 4096, 'IXANY' => 2048, 'IGNPAR' => 4, 'CREAD' => 128, 'CLOCAL' => 2048,
          'HUPCL' => 1024, 'VMIN' => 6, 'VTIME' => 5, 'TCSANOW' => 0, 'F_GETFL' => 3, 'F_SETFL' => 4, }
      end

      class Termios < FFI::Struct #:nodoc:
        # This struct has 2 version I've encountered, both with different sizes for cc_c
        # The simple solution is to simply ignore anything after cc_c and add some padding bytes to avoid memory corruption
        # Because of this hackyness, custom Baud rates are not supported
        layout  :c_iflag, :uint,
                :c_oflag, :uint,
                :c_cflag, :uint,
                :c_lflag, :uint,
                :c_line, :uchar,
                :cc_c, [:uchar, 64]
      end
    end
  end
end