module CatarsePaypalExpress
  class Interface
    def account_path
      false
    end

    def name
      'paypal_express'
    end

    def can_do_refund?
      true
    end

    def direct_refund(contribution)
      CatarsePaypalExpress::ContributionActions.new(contribution).refund
    end

    def fee_calculator(value)
      TransactionAdditionalFeeCalculator.new(value)
    end

    def locale
      'en'
    end

    def payment_path(resource)
      key = "#{ActiveModel::Naming.param_key(resource)}_id"
      CatarsePaypalExpress::Engine.
        routes.url_helpers.review_path(key => resource)
    end

    def payout_class
      nil
    end

    def review_path(contribution)
      CatarsePaypalExpress::Engine.routes.url_helpers.review_paypal_express_path(contribution)
    end
  end
end
