module CatarsePaypalExpress
  class PaypalExpressController < ApplicationController
    include ActiveMerchant::Billing::Integrations

    layout :false

    I18N_SCOPE = 'projects.contributions.checkout'
    helper_method :resource_params

    def review
    end

    def pay
      begin
        attributes = params.merge(
          pay_fee:     params[:payment][:pay_fee],
          resource_id: resource_params,
          user_ip:     request.remote_ip
        )
        payment = PaymentSetup.new(resource, attributes)
        payment.perform

        redirect_to payment.checkout_url
      rescue Exception => e
        Rails.logger.info "-----> #{e.inspect}"
        flash.alert = t('paypal_error', scope: I18N_SCOPE)
        redirect_to new_resource_path
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
        redirect_to resource_path
      rescue Exception => e
        Rails.logger.info "-----> #{e.inspect}"
        flash.alert = t('paypal_error', scope: I18N_SCOPE)
        redirect_to new_resource_path
      end
    end

    def cancel
      flash.alert = t('paypal_cancel', scope: I18N_SCOPE)
      redirect_to new_resource_path
    end

    def ipn
      attributes   = resource_params.merge(params).merge(raw: request.raw_post)
      notification = Notification.new(resource, attributes)
      if notification.valid?
        notification.save
      else
        return render status: 500, nothing: true
      end
      return render status: 200, nothing: true
    rescue Exception => e
      return render status: 500, text: e.inspect
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

    private

    def resource_params
      @resource_params ||= Hash[*params.slice(:contribution_id, :match_id).first]
    end

    def resource_path
      main_app.public_send("project_#{resource_type}_path",
        id:         resource,
        project_id: resource.project
      )
    end

    def new_resource_path
      main_app.public_send("new_project_#{resource_type}_path", resource.project)
    end

    def resource_type
      resource_params.keys.first[0..-4]
    end
  end
end
