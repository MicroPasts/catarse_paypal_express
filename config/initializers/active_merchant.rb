ActiveMerchant::Billing::PaypalExpressGateway.default_currency = (PaymentEngine.configuration[:currency_charge] rescue nil) || 'BRL'

if Configuration[:paypal_test]
  ActiveMerchant::Billing::Base.mode = :test
end
