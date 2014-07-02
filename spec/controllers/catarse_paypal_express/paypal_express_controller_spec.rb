require 'spec_helper'

describe CatarsePaypalExpress::PaypalExpressController do
  routes { CatarsePaypalExpress::Engine.routes }

  I18N_SCOPE = CatarsePaypalExpress::PaypalExpressController::I18N_SCOPE
  before do
    PaymentEngine.stub(:create_payment_notification)
    controller.stub(:main_app).and_return(main_app)
    controller.stub(:current_user).and_return(current_user)
    controller.stub(:gateway).and_return(gateway) # to be removed
    allow_any_instance_of(CatarsePaypalExpress::Payment).to receive(:gateway).and_return(gateway)
    controller.stub(:resource).and_return(contribution)
  end

  subject{ response }
  let(:gateway){ double('gateway') }
  let(:main_app){ double('main_app') }
  let(:current_user) { double('current_user') }
  let(:project){ double('project', id: 1, name: 'test project') }
  let(:contribution){ double('contribution', {
    id: 1,
    key: 'contribution key',
    payment_id: 'payment id',
    project: project,
    pending?: true,
    value: 20,
    display_value: 'R$ 20,00',
    price_in_cents: 2000,
    user: current_user,
    payer_name: 'foo',
    payer_email: 'foo@bar.com',
    payment_token: 'token',
    address_street: 'test',
    address_number: '123',
    address_complement: '123',
    address_neighbourhood: '123',
    address_city: '123',
    address_state: '123',
    address_zip_code: '123',
    address_phone_number: '123',
    payment_method: 'paypal_express'
  }) }

  describe "GET review" do
    before do
      get :review, id: contribution.id
    end
    it{ should render_template(:review) }
  end

  describe "POST pay" do
    let(:params) do
      {
        "utf8"=>"✓",
        "authenticity_token"=>"Pe5Mz1Yg80krG9XV8NZm4dPqBxfwVeVPJM+oRFQOBZ4=",
        "payment"=>{
          "pay_fee"=>"1",
        },
        "commit"=>"Confirm payment",
        "contribution_id"=>contribution.id.to_s
      }
    end

    context 'when successul' do
      before do
        allow(main_app).to     receive(:new_project_contribution_path).and_return('success url')
        allow(gateway).to      receive(:redirect_url_for).with('ABCD').and_return('success url')
        allow(gateway).to      receive(:setup_purchase).and_return(success_response)
        allow(contribution).to receive(:update_attributes)
      end
      let(:success_response) do
        double('success_response',
          token:  'ABCD',
          params: { 'correlation_id' => '123' }
        )
      end

      it 'setups purchase using payment service' do
        expect(gateway).to receive(:setup_purchase).with(
          anything,
          hash_including(
            :cancel_return_url,
            :currency_code,
            :description,
            :ip,
            :notify_url,
            :return_url,
          )
        ).and_return(success_response)
        post :pay, params
      end

      context 'when user is paying fees' do
        it 'charge calculator\'s gross_amount in the service' do
          allow_any_instance_of(
            CatarsePaypalExpress::TransactionAdditionalFeeCalculator
          ).to receive(:gross_amount).and_return(42.0)
          expect(gateway).to receive(:setup_purchase).with(
            4200,
            anything
          ).and_return(success_response)
          post :pay, params
        end
      end

      context 'when user is not paying fees' do
        before { params['payment']['pay_fee'] = '0' }

        it 'charge calculator\'s gross_amount in the service' do
          allow_any_instance_of(
            CatarsePaypalExpress::TransactionInclusiveFeeCalculator
          ).to receive(:gross_amount).and_return(42.0)
          expect(gateway).to receive(:setup_purchase).with(
            4200,
            anything
          ).and_return(success_response)
          post :pay, params
        end
      end

      it 'updates contribution with payment information' do
        expect(contribution).to receive(:update_attributes).with(
          payment_method: 'paypal_express',
          payment_token:  'ABCD'
        )
        post :pay, params
      end

      it 'redirects to successful contribution page' do
        post :pay, params
        expect(response).to redirect_to('success url')
      end
    end

    context 'when response raises a exception' do
      before do
        allow(gateway).to receive(:setup_purchase).and_raise(StandardError)
        allow(main_app).to receive(:new_project_contribution_path).and_return('error url')
      end

      it 'should assign flash error' do
        post :pay, params
        expect(flash[:alert]).to eql(I18n.t('paypal_error', scope: I18N_SCOPE))
      end

      it 'redirects to new contribution page' do
        post :pay, params
        expect(response).to redirect_to('error url')
      end
    end
  end

  describe 'GET success' do
    let(:success_details) do
      double('success_details',
        params: {
          'checkout_status' => 'PaymentActionCompleted',
          'transaction_id'  => '12345'
        }
      )
    end
    let(:params) do
      {
        :contribution_id=>contribution.id.to_s,
        :extra_data=>{
          :payer_id=>"J6QPTZJ3VUYEC",
          :resource_id=>{"contribution_id"=>contribution.id.to_s},
          :user_ip=>"85.179.175.126",
          "timestamp"=>"2014-07-02T11:16:54Z",
          "ack"=>"Success",
          "correlation_id"=>"644ae52867181",
          "version"=>"72",
          "build"=>"11624049",
          "token"=>"EC-7UD01139H9289551L",
          "transaction_id"=>"5S529942KX785625K",
          "parent_transaction_id"=>nil,
          "receipt_id"=>nil,
          "transaction_type"=>"express-checkout",
          "payment_type"=>"instant",
          "payment_date"=>"2014-07-02T11:16:54Z",
          "gross_amount"=>"20.00",
          "gross_amount_currency_id"=>"GBP",
          "fee_amount"=>"0.88",
          "fee_amount_currency_id"=>"GBP",
          "tax_amount"=>"0.00",
          "tax_amount_currency_id"=>"GBP",
          "exchange_rate"=>nil,
          "payment_status"=>"Completed",
          "pending_reason"=>"none",
          "reason_code"=>"none",
          "protection_eligibility"=>"Eligible",
          "protection_eligibility_type"=>"ItemNotReceivedEligible,UnauthorizedPaymentEligible",
          "secure_merchant_account_id"=>"36X593ULD53T6",
          "success_page_redirect_requested"=>"false",
          "Token"=>"EC-7UD01139H9289551L",
          "PaymentInfo"=>{
            "TransactionID"=>"5S529942KX785625K",
            "ParentTransactionID"=>nil,
            "ReceiptID"=>nil,
            "TransactionType"=>"express-checkout",
            "PaymentType"=>"instant",
            "PaymentDate"=>"2014-07-02T11:16:54Z",
            "GrossAmount"=>"20.00",
            "FeeAmount"=>"0.88",
            "TaxAmount"=>"0.00",
            "ExchangeRate"=>nil,
            "PaymentStatus"=>"Completed",
            "PendingReason"=>"none",
            "ReasonCode"=>"none",
            "ProtectionEligibility"=>"Eligible",
            "ProtectionEligibilityType"=>"ItemNotReceivedEligible,UnauthorizedPaymentEligible",
            "SellerDetails"=>{
              "SecureMerchantAccountID"=>"36X593ULD53T6"
            }
          },
          "SuccessPageRedirectRequested"=>"false"
        }
      }
    end

    before do
      allow(main_app).to receive(:new_project_contribution_path).and_return('create contribution url')
      allow(gateway).to  receive(:purchase).and_return(success_details)
    end

    it 'completes the payment' do
      expect(gateway).to receive(:purchase).with(
        contribution.price_in_cents,
        ip:       request.remote_ip,
        payer_id: params[:PayerID],
        token:    contribution.payment_token
      ).and_return(success_details)
      get :success, params
    end

    context 'when purchase is successful' do
      before do
        allow(contribution).to receive(:confirm!)
        allow(contribution).to receive(:update_attributes)
        allow(main_app).to     receive(:project_contribution_path).
          and_return('contribution url')
      end

      it 'fetches more information about transaction' do
        expect_any_instance_of(CatarsePaypalExpress::Event).to receive(:process)
        get :success, params
      end

      it 'defines the payment_id in the contribution' do
        expect(contribution).to receive(:update_attributes).with(payment_id: '12345')
        get :success, params
      end

      it 'confirms contribution' do
        expect(contribution).to receive(:confirm!)
        get :success, params
      end

      it 'redirects to new contribution page' do
        get :success, params
        expect(response).to redirect_to('contribution url')
      end

      it 'should assign flash message' do
        get :success, params
        expect(flash[:notice]).to eql(I18n.t('success', scope: I18N_SCOPE))
      end
    end

    context 'when paypal purchase raises some error' do
      before do
        allow(gateway).to receive(:purchase).and_raise('error')
      end

      it 'should assign flash error' do
        get :success, params
        expect(flash[:alert]).to eql(I18n.t('paypal_error', scope: I18N_SCOPE))
      end

      it 'redirects to new contribution url' do
        get :success, params
        expect(response).to redirect_to('create contribution url')
      end
    end
  end

  describe 'GET cancel' do
    before do
      allow(main_app).to receive(:new_project_contribution_path).
        and_return('create contribution url')
    end

    it 'should show for user the flash message' do
      get :cancel, id: contribution.id, locale: 'en'
      expect(flash[:alert]).to eql(I18n.t('paypal_cancel', scope: I18N_SCOPE))
    end

    it 'redirects to new contribution url' do
      get :cancel, id: contribution.id, locale: 'en'
      expect(response).to redirect_to('create contribution url')
    end
  end

  describe 'POST ipn' do
    let(:ipn_data) do
      {
        "mc_gross" => "50.00",
        "protection_eligibility" => "Eligible",
        "address_status" => "unconfirmed",
        "payer_id" => "S7Q8X88KMGX5S",
        "tax" => "0.00",
        "address_street" => "Rua Tatui, 40 ap 81\r\nJardins",
        "payment_date" => "09:03:01 Nov 05, 2012 PST",
        "payment_status" => "Completed",
        "charset" => "windows-1252",
        "address_zip" => "01409-010",
        "first_name" => "Paula",
        "mc_fee" => "3.30",
        "address_country_code" => "BR",
        "address_name" => "Paula Rizzo",
        "notify_version" => "3.7",
        "custom" => "",
        "payer_status" => "verified",
        "address_country" => "Brazil",
        "address_city" => "Sao Paulo",
        "quantity" => "1",
        "verify_sign" => "ALBe4QrXe2sJhpq1rIN8JxSbK4RZA.Kfc5JlI9Jk4N1VQVTH5hPYOi2S",
        "payer_email" => "paula.rizzo@gmail.com",
        "txn_id" => "3R811766V4891372K",
        "payment_type" => "instant",
        "last_name" => "Rizzo",
        "address_state" => "SP",
        "receiver_email" => "financeiro@catarse.me",
        "payment_fee" => "",
        "receiver_id" => "BVUB4EVC7YCWL",
        "txn_type" => "express_checkout",
        "item_name" => "Back project",
        "mc_currency" => "BRL",
        "item_number" => "",
        "residence_country" => "BR",
        "handling_amount" => "0.00",
        "transaction_subject" => "Back project",
        "payment_gross" => "",
        "shipping" => "0.00",
        "ipn_track_id" => "5865649c8c27"
      }
    end
    let(:contribution) do
      double(:contribution,
        payment_id:     ipn_data['txn_id'],
        payment_method: 'paypal_express'
      )
    end
    let(:notification) { double }

    before do
      allow_any_instance_of(
        CatarsePaypalExpress::Notification
      ).to receive(:notification).and_return(notification)
    end

    context 'when is a valid ipn data' do
      before do
        allow(contribution).to receive(:update_attributes)
        allow(notification).to receive(:acknowledge).and_return(true)
        allow_any_instance_of(CatarsePaypalExpress::Event).to receive(:process)
      end

      it 'validates notification' do
        expect(notification).to receive(:acknowledge)
        post :ipn, ipn_data
      end

      it 'fetches more information about transaction' do
        expect_any_instance_of(
          CatarsePaypalExpress::Event
        ).to receive(:process)
        post :ipn, ipn_data
      end

      it 'updates contribution with new information' do
        expect(contribution).to receive(:update_attributes).with(
          payer_email:         ipn_data['payer_email'],
          payment_service_fee: ipn_data['mc_fee']
        )
        post :ipn, ipn_data
      end

      it 'responds with 200 HTTP status' do
        post :ipn, ipn_data
        expect(subject.status).to eql(200)
      end

      it 'renders empty body' do
        post :ipn, ipn_data
        expect(subject.body.strip).to be_empty
      end
    end

    context "when is not valid ipn data" do
      before do
        notification.stub(:acknowledge).and_return(false)
      end
      let(:ipn_data) do
        {
          "mc_gross" => "50.00",
          "payment_status" => 'confirmed',
          "txn_id" => "3R811766V4891372K",
          'payer_email' => 'fake@email.com',
          'mc_fee' => '0.0'
        }
      end

      it 'validates notification' do
        expect(notification).to receive(:acknowledge)
        post :ipn, ipn_data
      end

      it 'skips fetching for more information about transaction' do
        expect_any_instance_of(
          CatarsePaypalExpress::Event
        ).to_not receive(:process)
        post :ipn, ipn_data
      end

      it 'skips any update to contribution with received data' do
        expect(contribution).to_not receive(:update_attributes).with(
          payer_email:         ipn_data['payer_email'],
          payment_service_fee: ipn_data['mc_fee']
        )
        post :ipn, ipn_data
      end

      it 'responds with 500 HTTP status' do
        post :ipn, ipn_data
        expect(subject.status).to eql(500)
      end

      it 'renders empty body' do
        post :ipn, ipn_data
        expect(subject.body.strip).to be_empty
      end
    end
  end

  describe '#resource' do
    subject { controller }
    before do
      allow(controller).to receive(:params).and_return(params)
    end

    context 'when a contribution id is given' do
      before do
      end
      let(:params) { { contribution_id: '1' } }

      it 'delegates to PaymentEngine.find_payment passing contribution_id' do
        allow(PaymentEngine).to receive(:find_payment).with(contribution_id: '1').and_return(contribution)
        expect(subject.resource).to eql(contribution)
      end
    end

    context "when we have an txn_id that does not return contribution but a parent_txn_id that does" do
      before do
        allow(PaymentEngine).to receive(:find_payment).with(payment_id: '1').and_return(nil)
      end
      let(:params) { { 'txn_id' => '1', 'parent_txn_id' => '2' } }

      it 'delegates to PaymentEngine.find_payment passing parent_txn_id' do
        allow(PaymentEngine).to receive(:find_payment).with(payment_id: '2').and_return(contribution)
        expect(subject.resource).to eql(contribution)
      end
    end

    context "when we do not have any kind of id" do
      before do
        allow(controller).to receive(:resource).and_call_original
      end
      let(:params) { {} }

      it 'returns nil' do
        expect(subject.resource).to be_nil
      end
    end

    context "when we have an txn_id" do
      let(:params) { { 'txn_id' => '1' } }

      it 'delegates to PaymentEngine.find_payment passing txn_id' do
        allow(PaymentEngine).to receive(:find_payment).with(payment_id: '1').and_return(contribution)
        expect(subject.resource).to eql(contribution)
      end
    end
  end
end
