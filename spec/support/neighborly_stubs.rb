class Configuration
  def self.[](value)
    '42'
  end
end

class PaymentEngine
  class << self
    def create_payment_notification(*); end
    def register(*);                    end
  end

  def initialize(*); end
  def save(*);       end
end
