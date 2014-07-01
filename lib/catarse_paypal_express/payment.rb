module CatarsePaypalExpress
  class Payment
    attr_reader :resource, :attributes

    def initialize(resource, attributes)
      @resource, @attributes = resource, attributes
    end

    def process_paypal_message(data)
      extra_data = if data['charset']
        JSON.parse(data.to_json.force_encoding(data['charset']).encode('utf-8'))
      else
        data
      end
      PaymentEngine.create_payment_notification(
        attributes.fetch(:resource_id).merge(extra_data: extra_data)
      )

      if data['checkout_status'] == 'PaymentActionCompleted'
        resource.confirm!
      elsif data['payment_status']
        case data['payment_status'].downcase
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

    def gateway
      @gateway ||= CatarsePaypalExpress::Gateway.instance
    end

    def amount_in_cents
      (fee_calculator.gross_amount * 100).round
    end

    def fee_calculator
      @fee_calculator and return @fee_calculator

      calculator_class = if ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include? attributes[:pay_fee]
        TransactionAdditionalFeeCalculator
      else
        TransactionInclusiveFeeCalculator
      end

      @fee_calculator = calculator_class.new(resource.value)
    end
  end
end
