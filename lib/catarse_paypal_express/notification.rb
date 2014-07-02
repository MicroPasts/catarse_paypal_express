module CatarsePaypalExpress
  class Notification
    attr_reader :attributes, :resource

    def initialize(resource, attributes)
      @resource, @attributes = resource, attributes
    end

    def save
      Event.new(resource, attributes).process
      resource.update_attributes(
        payer_email:         attributes['payer_email'],
        payment_service_fee: attributes['mc_fee']
      )
    end

    def valid?
      resource &&
        notification.acknowledge &&
        (resource.payment_method == Interface.new.name || resource.payment_method.nil?)
    end

    protected

    def notification
      @notification ||= Paypal::Notification.new(attributes[:raw])
    end
  end
end
