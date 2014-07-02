module CatarsePaypalExpress
  class PaymentSetup < Payment
    include Engine.routes.url_helpers

    attr_reader :response
    delegate :token, to: :response

    def perform
      @response = gateway.setup_purchase(amount_in_cents,
        cancel_return_url: cancel_return_url,
        currency_code:     ::Configuration[:currency_charge],
        description:       description,
        ip:                attributes.fetch(:user_ip),
        notify_url:        notify_url,
        return_url:        return_url
      )

      Event.new(resource, attributes.merge(response.params)).process
      resource.update_attributes(
        payment_method:                   CatarsePaypalExpress::Interface.new.name,
        payment_service_fee_paid_by_user: fees_paid_user?,
        payment_token:                    response.token
      )
    end

    def checkout_url
      gateway.redirect_url_for(token)
    end

    protected

    def description
      I18n.t('paypal_description',
        scope:        PaypalExpressController::I18N_SCOPE,
        project_name: resource.project.name,
        value:        "#{fee_calculator.gross_amount} #{::Configuration[:currency_charge]}"
      )
    end

    def return_url
      success_url(
        attributes.fetch(:resource_id).merge(host: Configuration[:base_url])
      )
    end

    def cancel_return_url
      cancel_url(
        attributes.fetch(:resource_id).merge(host: Configuration[:base_url])
      )
    end

    def notify_url
      ipn_url(host: Configuration[:base_url])
    end
  end
end
