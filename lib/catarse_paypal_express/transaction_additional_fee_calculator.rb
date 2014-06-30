require 'float_extensions'

module CatarsePaypalExpress
  class TransactionAdditionalFeeCalculator < TransactionFeeCalculatorBase
    using FloatExtensions

    def net_amount
      transaction_value.to_f.floor_with_two_decimal_places
    end
  end
end

