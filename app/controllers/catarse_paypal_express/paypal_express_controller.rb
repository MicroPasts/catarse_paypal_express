module CatarsePaypalExpress
  class PaypalExpressController < ApplicationController
    include ActiveMerchant::Billing::Integrations

    skip_before_filter :force_http
    SCOPE = "projects.contributions.checkout"
    layout :false
    helper_method :resource_params

    def review
    end

    def pay
      begin
        description = t('paypal_description',
          scope:        SCOPE,
          project_name: resource.project.name,
          value:        "#{fee_calculator.gross_amount} #{::Configuration[:currency_charge]}"
        )
        response = gateway.setup_purchase(amount_in_cents,
          cancel_return_url: cancel_url(resource_params),
          currency_code:     ::Configuration[:currency_charge],
          description:       description,
          ip:                request.remote_ip,
          notify_url:        ipn_paypal_express_index_url,
          return_url:        success_url(resource_params)
        )

        process_paypal_message(response.params)
        resource.update_attributes(
          payment_method: CatarsePaypalExpress::Interface.new.name,
          payment_token:  response.token
        )

        redirect_to gateway.redirect_url_for(response.token)
      rescue Exception => e
        Rails.logger.info "-----> #{e.inspect}"
        flash.alert = t('paypal_error', scope: SCOPE)
        return redirect_to main_app.new_project_contribution_path(resource.project)
      end
    end

    def success
      begin
        purchase = gateway.purchase(amount_in_cents, {
          ip:       request.remote_ip,
          payer_id: params[:PayerID],
          token:    resource.payment_token
        })

        # we must get the deatils after the purchase in order to get the transaction_id
        process_paypal_message(purchase.params)
        if purchase.params['transaction_id']
          resource.update_attributes(
            payment_id: purchase.params['transaction_id']
          )
        end

        flash.notice = t('success', scope: SCOPE)
        redirect_to main_app.project_contribution_path(project_id: resource.project, id: resource)
      rescue Exception => e
        Rails.logger.info "-----> #{e.inspect}"
        flash.alert = t('paypal_error', scope: SCOPE)
        return redirect_to main_app.new_project_contribution_path(resource.project)
      end
    end

    def cancel
      flash.alert = t('paypal_cancel', scope: SCOPE)
      redirect_to main_app.new_project_contribution_path(resource.project)
    end

    def ipn
      if resource && notification.acknowledge &&
        (resource.payment_method == CatarsePaypalExpress::Interface.new.name || resource.payment_method.nil?)
        process_paypal_message params
        resource.update_attributes({
          :payment_service_fee => params['mc_fee'],
          :payer_email => params['payer_email']
        })
      else
        return render status: 500, nothing: true
      end
      return render status: 200, nothing: true
    rescue Exception => e
      return render status: 500, text: e.inspect
    end

    def process_paypal_message(data)
      extra_data = if data['charset']
        JSON.parse(data.to_json.force_encoding(data['charset']).encode('utf-8'))
      else
        data
      end
      PaymentEngine.create_payment_notification(
        resource_params.merge(extra_data: extra_data)
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

    def resource
      @resource ||= begin
        payment_id = params.slice(:txn_id, :parent_txn_id).compact.first.try(:last)
        filter     = if payment_id.present?
          { payment_id: payment_id }
        else
          resource_params
        end
        PaymentEngine.find_payment(filter.with_indifferent_access)
      end
    end

    def resource_params
      @resource_params ||= Hash[*params.slice(:contribution_id, :match_id).first]
    end

    protected

    def notification
      @notification ||= Paypal::Notification.new(request.raw_post)
    end

    def amount_in_cents
      (fee_calculator.gross_amount * 100).round
    end

    def fee_calculator
      @fee_calculator and return @fee_calculator

      calculator_class = if ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include? params[:pay_fee]
        TransactionAdditionalFeeCalculator
      else
        TransactionInclusiveFeeCalculator
      end

      @fee_calculator = calculator_class.new(resource.value)
    end
  end
end
