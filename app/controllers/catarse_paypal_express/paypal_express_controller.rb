class CatarsePaypalExpress::PaypalExpressController < ApplicationController
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
        value:        resource.display_value
      )
      response = gateway.setup_purchase(resource.price_in_cents, {
        ip:                request.remote_ip,
        return_url:        success_url(resource_params),
        cancel_return_url: cancel_url(resource_params),
        currency_code:     ::Configuration[:currency_charge],
        description:       description,
        notify_url:        ipn_paypal_express_index_url
      })

      process_paypal_message(response.params)
      resource.update_attributes(
        payment_method: CatarsePaypalExpress::Interface.new.name,
        payment_token:  response.token
      )

      redirect_to gateway.redirect_url_for(response.token)
    rescue Exception => e
      Rails.logger.info "-----> #{e.inspect}"
      flash[:failure] = t('paypal_error', scope: SCOPE)
      return redirect_to main_app.new_project_contribution_path(resource.project)
    end
  end

  def success
    begin
      purchase = gateway.purchase(resource.price_in_cents, {
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
    extra_data = (data['charset'] ? JSON.parse(data.to_json.force_encoding(data['charset']).encode('utf-8')) : data)
    PaymentEngine.create_payment_notification(
      resource_params.merge(extra_data: extra_data)
    )

    if data["checkout_status"] == 'PaymentActionCompleted'
      resource.confirm!
    elsif data["payment_status"]
      case data["payment_status"].downcase
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
    @resource ||= if params['txn_id']
        PaymentEngine.find_payment(payment_id: params['txn_id']) ||
          (params['parent_txn_id'] && PaymentEngine.find_payment(payment_id: params['parent_txn_id']))
      else
        # :contribution_id => Contribution
        resource_class = resource_params.keys.first[0..-4].camelize.constantize
        resource_class.find(resource_params.values.first)
      end
  end

  def resource_params
    @resource_param ||= Hash[*params.slice(:contribution_id, :match_id).first]
  end

  protected

  def notification
    @notification ||= Paypal::Notification.new(request.raw_post)
  end
end
