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

      calculator_class = if ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include? attributes[:pay_fee]
        TransactionAdditionalFeeCalculator
      else
        TransactionInclusiveFeeCalculator
      end

      @fee_calculator = calculator_class.new(resource.value)
    end
  end
end
