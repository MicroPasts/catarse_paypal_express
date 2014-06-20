ActiveMerchant::Billing::PaypalExpressGateway.default_currency = (PaymentEngine.configuration[:currency_charge] rescue nil) || 'BRL'
ActiveMerchant::Billing::Base.mode = :test if (PaymentEngine.configuration[:paypal_test] == 'true' rescue nil)
