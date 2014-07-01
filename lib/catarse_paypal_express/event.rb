module CatarsePaypalExpress
  class Event
    attr_reader :attributes, :resource

    def initialize(resource, attributes)
      @resource, @attributes = resource, attributes
    end

    def process
      extra_attributes = if attributes['charset']
        JSON.parse(attributes.to_json.force_encoding(attributes['charset']).encode('utf-8'))
      else
        attributes
      end
      PaymentEngine.create_payment_notification(
        attributes.fetch(:resource_id).merge(extra_data: extra_attributes)
      )

      if attributes['checkout_status'] == 'PaymentActionCompleted'
        resource.confirm!
      elsif attributes['payment_status']
        case attributes['payment_status'].downcase
        when 'completed'
          resource.confirm!
        when 'refunded'
          resource.refund!
        when 'canceled_reversal'
          resource.cancel!
        when 'expired', 'denied'
          resource.pendent!
        else
          resource.wait_confirmation! if resource.pending?
        end
      end
    end
  end
end
