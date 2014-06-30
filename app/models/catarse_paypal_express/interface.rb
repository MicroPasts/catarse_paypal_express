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
      params = {
        "#{ActiveModel::Naming.param_key(resource)}_id".to_sym => resource.to_param
      }
      CatarsePaypalExpress::Engine.routes.url_helpers.review_path(params)
    end

    def payout_class
      nil
    end
  end
end
