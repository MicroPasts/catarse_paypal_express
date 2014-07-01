module CatarsePaypalExpress
  class PaypalExpressController < ApplicationController
    include ActiveMerchant::Billing::Integrations

    I18N_SCOPE = 'projects.contributions.checkout'
    helper_method :resource_params

    def review
    end

    def pay
      begin
        attributes = params.merge(
          resource_id: resource_params,
          user_ip:     request.remote_ip
        )
        payment = PaymentSetup.new(resource, attributes)
        payment.perform

        redirect_to payment.checkout_url
      rescue Exception => e
        Rails.logger.info "-----> #{e.inspect}"
        flash.alert = t('paypal_error', scope: I18N_SCOPE)
        redirect_to main_app.new_project_contribution_path(resource.project)
      end
    end

    def success
      begin
        attributes = {
          payer_id:    params[:PayerID],
          resource_id: resource_params,
          user_ip:     request.remote_ip
        }
        checkout = PaymentCheckout.new(resource, attributes)
        checkout.perform

        flash.notice = t('success', scope: I18N_SCOPE)
        redirect_to main_app.project_contribution_path(
          id:         resource,
          project_id: resource.project
        )
      rescue Exception => e
        Rails.logger.info "-----> #{e.inspect}"
        flash.alert = t('paypal_error', scope: I18N_SCOPE)
        redirect_to main_app.new_project_contribution_path(resource.project)
      end
    end

    def cancel
      flash.alert = t('paypal_cancel', scope: I18N_SCOPE)
      redirect_to main_app.new_project_contribution_path(resource.project)
    end

    def ipn
      if resource && notification.acknowledge &&
        (resource.payment_method == CatarsePaypalExpress::Interface.new.name || resource.payment_method.nil?)

        process_paypal_message(params)
        resource.update_attributes(
          payer_email:         params[:payer_email],
          payment_service_fee: params[:mc_fee]
        )
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
