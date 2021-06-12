module Asterisk
  module Agi
    class Channel
      attr_reader :tech, :name, :id
      alias :technology :tech
      alias :type :tech

      def initialize(str)
        /\A(?<tech>[A-z]+)\/(?<name>.+)\-(?<id>.+)\z/ =~ str
        @tech = tech
        @name = name
        @id = id
      end

      def name_with_tech
        "#{tech}/#{name}"
      end
      alias :name_with_technology :name_with_tech

      def to_s
        str = name_with_tech
        str << "-#{id}" if id
        str
      end

    end
  end
end
