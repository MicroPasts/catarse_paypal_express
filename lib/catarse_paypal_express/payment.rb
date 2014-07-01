module CatarsePaypalExpress
  class Payment
    include Engine.routes.url_helpers

    attr_reader :resource, :attributes, :response
    delegate :token, to: :response

    def initialize(resource, attributes)
      @resource, @attributes = resource, attributes
    end

    def setup
      description = I18n.t('paypal_description',
        scope:        PaypalExpressController::I18N_SCOPE,
        project_name: resource.project.name,
        value:        "#{fee_calculator.gross_amount} #{::Configuration[:currency_charge]}"
      )
      @response = gateway.setup_purchase(amount_in_cents,
        cancel_return_url: cancel_return_url,
        currency_code:     ::Configuration[:currency_charge],
        description:       description,
        ip:                attributes.fetch(:user_ip),
        notify_url:        notify_url,
        return_url:        return_url
      )

      process_paypal_message(response.params)
      resource.update_attributes(
        payment_method: CatarsePaypalExpress::Interface.new.name,
        payment_token:  response.token
      )
    end

    def process_paypal_message(data)
      extra_data = if data['charset']
        JSON.parse(data.to_json.force_encoding(data['charset']).encode('utf-8'))
      else
        data
      end
      PaymentEngine.create_payment_notification(
        attributes.fetch(:resource_id).merge(extra_data: extra_data)
      )

      if data['checkout_status'] == 'PaymentActionCompleted'
        resource.confirm!
      elsif data['payment_status']
        case data['payment_status'].downcase
        when 'completed'
          resource.confirm!
        when 'refunded'
          resource.refund!
        when 'canceled_reversal'
          resource.cancel!
        when 'expired', 'denied'
          resource.pendent!
        else
          resource.wait_confirmation! if resource.pending?
        end
      end
    end

    def gateway
      @gateway ||= CatarsePaypalExpress::Gateway.instance
    end

    protected

    def checkout_url
      gateway.redirect_url_for(token)
    end

    def return_url
      success_url(
        attributes.fetch(:resource_id),
        host: Configuration[:base_url]
      )
    end

    def cancel_return_url
      cancel_url(
        attributes.fetch(:resource_id),
        host: Configuration[:base_url]
      )
    end

    def notify_url
      ipn_paypal_express_index_url(
        host: Configuration[:base_url]
      )
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
