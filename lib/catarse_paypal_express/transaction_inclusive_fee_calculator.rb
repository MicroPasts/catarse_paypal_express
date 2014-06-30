require 'float_extensions'

module CatarsePaypalExpress
  class TransactionInclusiveFeeCalculator < TransactionFeeCalculatorBase
    using FloatExtensions

    # Base calculation of fees
    # 3.4% + 20p
    def net_amount
      ((transaction_value - 0.2) / 1.034).floor_with_two_decimal_places
    end
  end
end
