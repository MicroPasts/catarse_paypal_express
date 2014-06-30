class Configuration
  def self.[](value)
    '42'
  end
end

class Contribution
  def self.find(*)
    new
  end

  def display_value(*); end
  def price_in_cents(*); end

  def project
    @project ||= Project.new
  end
end

class PaymentEngine
  class << self
    def create_payment_notification(*); end
    def find_payment(*);                end
    def register(*);                    end
  end

  def initialize(*); end
  def save(*);       end
end

class Project
  def name(*); end
end
