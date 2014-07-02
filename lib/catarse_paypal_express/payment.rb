module CatarsePaypalExpress
  class Payment
    attr_reader :resource, :attributes

    def initialize(resource, attributes)
      @resource, @attributes = resource, attributes
    end

    def gateway
      @gateway ||= CatarsePaypalExpress::Gateway.instance
    end

    def amount_in_cents
      (fee_calculator.gross_amount * 100).round
    end

    def fee_calculator
      @fee_calculator and return @fee_calculator

      calculator_class = if fees_paid_user?
        TransactionAdditionalFeeCalculator
      else
        TransactionInclusiveFeeCalculator
      end

      @fee_calculator = calculator_class.new(resource.value)
    end

    def fees_paid_user?
      ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include? attributes[:pay_fee]
    end
  end
end
