ActiveMerchant::Billing::PaypalExpressGateway.default_currency = Configuration[:currency_charge]

if Configuration[:paypal_test]
  ActiveMerchant::Billing::Base.mode = :test
end
