module CatarsePaypalExpress
  class PaymentCheckout < Payment
    def perform
      purchase = gateway.purchase(amount_in_cents,
        ip:       attributes.fetch(:user_ip),
        payer_id: attributes.fetch(:payer_id),
        token:    resource.payment_token
      )

      process_paypal_message(purchase.params)
      if purchase.params['transaction_id']
        resource.update_attributes(
          payment_id: purchase.params['transaction_id']
        )
      end
    end
  end
end
