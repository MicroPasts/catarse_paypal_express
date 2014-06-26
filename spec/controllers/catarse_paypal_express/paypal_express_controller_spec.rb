# encoding: utf-8

require 'spec_helper'

describe CatarsePaypalExpress::PaypalExpressController do
  SCOPE = CatarsePaypalExpress::PaypalExpressController::SCOPE
  before do
    PaymentEngine.stub(:find_payment).and_return(contribution)
    PaymentEngine.stub(:create_payment_notification)
    controller.stub(:main_app).and_return(main_app)
    controller.stub(:current_user).and_return(current_user)
    controller.stub(:gateway).and_return(gateway)
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
    value: 10,
    display_value: 'R$ 10,00',
    price_in_cents: 1000,
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
    payment_method: ::Configuration[:currency_charge]
  }) }

  describe "GET review" do
    before do
      get :review, id: contribution.id, use_route: 'catarse_paypal_express'
    end
    it{ should render_template(:review) }
  end

  describe "POST pay" do
    context 'when response raises a exception' do
      before do
        allow(gateway).to receive(:setup_purchase).and_raise(StandardError)
        allow(main_app).to receive(:new_project_contribution_path).and_return('error url')
      end

      it 'should assign flash error' do
        post :pay, contribution_id: contribution.id, locale: 'en', use_route: 'catarse_paypal_express'
        expect(controller.flash[:failure]).to eql(I18n.t('paypal_error', scope: SCOPE))
      end

      it 'redirects to new contribution page' do
        post :pay, contribution_id: contribution.id, locale: 'en', use_route: 'catarse_paypal_express'
        expect(response).to redirect_to('error url')
      end
    end

    context 'when successul' do
      let(:success_response) do
        double('success_response',
          token:  'ABCD',
          params: { 'correlation_id' => '123' }
        )
      end

      before do
        allow(main_app).to receive(:new_project_contribution_path).and_return('success url')
        allow(gateway).to  receive(:redirect_url_for).with('ABCD').and_return('success url')
        allow(gateway).to  receive(:setup_purchase).and_return(success_response)
      end

      it 'setups purchase using payment service' do
        expect(gateway).to receive(:setup_purchase).with(
          contribution.price_in_cents,
          ip:                request.remote_ip,
          return_url:        'http://test.host/catarse_paypal_express/paypal_express/success?contribution_id=1',
          cancel_return_url: 'http://test.host/catarse_paypal_express/paypal_express/cancel?contribution_id=1',
          currency_code:     ::Configuration[:currency_charge],
          description:       I18n.t('paypal_description', scope: SCOPE, project_name: contribution.project.name, value: contribution.display_value),
          notify_url:        'http://test.host/catarse_paypal_express/payment/paypal_express/ipn'
        ).and_return(success_response)
        post :pay, contribution_id: contribution.id, locale: 'en', use_route: 'catarse_paypal_express'
      end

      it 'updates contribution with payment information' do
        expect(contribution).to receive(:update_attributes).with(
          payment_method: 'paypal_express',
          payment_token:  'ABCD'
        )
        post :pay, contribution_id: contribution.id, locale: 'en', use_route: 'catarse_paypal_express'
      end

      it 'redirects to successful contribution page' do
        post :pay, contribution_id: contribution.id, locale: 'en', use_route: 'catarse_paypal_express'
        expect(response).to redirect_to('success url')
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
        id:        contribution.id,
        locale:    'en',
        PayerID:   '123',
        use_route: 'catarse_paypal_express'
      }
    end

    before do
      allow(main_app).to receive(:new_project_contribution_path).and_return('create contribution url')
      allow(gateway).to  receive(:purchase).and_return(success_details)
    end

    it 'completes the payment' do
      gateway.should_receive(:purchase).with(
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
        expect(controller).to receive(:process_paypal_message).
          with(success_details.params)
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
        expect(flash[:notice]).to eql(I18n.t('success', scope: SCOPE))
      end
    end

    context 'when paypal purchase raises some error' do
      before do
        allow(gateway).to receive(:purchase).and_raise('error')
      end

      it 'fetches more information about transaction' do
        expect(controller).to receive(:process_paypal_message).
          with(success_details.params)
        get :success, params
      end

      it 'defines the payment_id in the contribution' do
        expect(contribution).to receive(:update_attributes).with(payment_id: '12345')
        get :success, params
      end

      it 'should assign flash error' do
        get :success, params
        expect(flash[:alert]).to eql(I18n.t('paypal_error', scope: SCOPE))
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
      get :cancel, id: contribution.id, locale: 'en', use_route: 'catarse_paypal_express'
      expect(flash[:alert]).to eql(I18n.t('paypal_cancel', scope: SCOPE))
    end

    it 'redirects to new contribution url' do
      get :cancel, id: contribution.id, locale: 'en', use_route: 'catarse_paypal_express'
      expect(response).to redirect_to('create contribution url')
    end
  end

  describe "POST ipn" do
    let(:ipn_data){ {"mc_gross"=>"50.00", "protection_eligibility"=>"Eligible", "address_status"=>"unconfirmed", "payer_id"=>"S7Q8X88KMGX5S", "tax"=>"0.00", "address_street"=>"Rua Tatui, 40 ap 81\r\nJardins", "payment_date"=>"09:03:01 Nov 05, 2012 PST", "payment_status"=>"Completed", "charset"=>"windows-1252", "address_zip"=>"01409-010", "first_name"=>"Paula", "mc_fee"=>"3.30", "address_country_code"=>"BR", "address_name"=>"Paula Rizzo", "notify_version"=>"3.7", "custom"=>"", "payer_status"=>"verified", "address_country"=>"Brazil", "address_city"=>"Sao Paulo", "quantity"=>"1", "verify_sign"=>"ALBe4QrXe2sJhpq1rIN8JxSbK4RZA.Kfc5JlI9Jk4N1VQVTH5hPYOi2S", "payer_email"=>"paula.rizzo@gmail.com", "txn_id"=>"3R811766V4891372K", "payment_type"=>"instant", "last_name"=>"Rizzo", "address_state"=>"SP", "receiver_email"=>"financeiro@catarse.me", "payment_fee"=>"", "receiver_id"=>"BVUB4EVC7YCWL", "txn_type"=>"express_checkout", "item_name"=>"Back project", "mc_currency"=>"BRL", "item_number"=>"", "residence_country"=>"BR", "handling_amount"=>"0.00", "transaction_subject"=>"Back project", "payment_gross"=>"", "shipping"=>"0.00", "ipn_track_id"=>"5865649c8c27"} }
    let(:contribution){ double(:contribution, :payment_id => ipn_data['txn_id'], :payment_method => 'PayPal' ) }
    let(:notification) { double }

    before do
      controller.stub(:notification).and_return(notification)
    end

    context "when payment_method is MoIP" do
      before do
        params = ipn_data.merge({ use_route: 'catarse_paypal_express' })

        notification.stub(:acknowledge).and_return(true)
        contribution.stub(:payment_method).and_return('MoIP')

        contribution.should_not_receive(:update_attributes)
        controller.should_not_receive(:process_paypal_message)

        notification.should_receive(:acknowledge)

        post :ipn, params
      end

      its(:status){ should == 500 }
      its(:body){ should == ' ' }
    end

    context "when is a valid ipn data" do
      before do
        params = ipn_data.merge({ use_route: 'catarse_paypal_express' })

        notification.stub(:acknowledge).and_return(true)

        contribution.should_receive(:update_attributes).with({
          payment_service_fee: ipn_data['mc_fee'],
          payer_email: ipn_data['payer_email']
        })
        controller.should_receive(:process_paypal_message).with(ipn_data.merge({
          "controller"=>"catarse_paypal_express/paypal_express",
          "action"=>"ipn"
        }))

        notification.should_receive(:acknowledge)

        post :ipn, params
      end

      its(:status){ should == 200 }
      its(:body){ should == ' ' }
    end

    context "when is not valid ipn data" do
      let(:ipn_data){ {"mc_gross"=>"50.00", "payment_status" => 'confirmed', "txn_id" => "3R811766V4891372K", 'payer_email' => 'fake@email.com', 'mc_fee' => '0.0'} }

      before do
        params = ipn_data.merge({ use_route: 'catarse_paypal_express' })

        notification.stub(:acknowledge).and_return(false)

        contribution.should_receive(:update_attributes).with({
          payment_service_fee: ipn_data['mc_fee'],
          payer_email: ipn_data['payer_email']
        }).never

        controller.should_receive(:process_paypal_message).with(ipn_data.merge({
          "controller"=>"catarse_paypal_express/paypal_express",
          "action"=>"ipn"
        })).never

        notification.should_receive(:acknowledge)

        post :ipn, params
      end

      its(:status){ should == 500 }
      its(:body){ should == ' ' }
    end
  end

  describe "#gateway" do
    before do
      controller.stub(:gateway).and_call_original
      PaymentEngine.stub(:configuration).and_return(paypal_config)
    end
    subject{ controller.gateway }
    context "when we have the paypal configuration" do
      let(:paypal_config) do
        { paypal_username: 'username', paypal_password: 'pass', paypal_signature: 'signature' }
      end
      before do
        ActiveMerchant::Billing::PaypalExpressGateway.should_receive(:new).with({
          login: PaymentEngine.configuration[:paypal_username],
          password: PaymentEngine.configuration[:paypal_password],
          signature: PaymentEngine.configuration[:paypal_signature]
        }).and_return('gateway instance')
      end
      it{ should == 'gateway instance' }
    end

    context "when we do not have the paypal configuration" do
      let(:paypal_config){ {} }
      before do
        ActiveMerchant::Billing::PaypalExpressGateway.should_not_receive(:new)
      end
      it{ should be_nil }
    end
  end

  describe "#resource" do
    subject{ controller.resource }
    context "when we have an id" do
      before do
        controller.stub(:params).and_return({'contribution_id' => '1'})
        PaymentEngine.should_receive(:find_payment).with(id: '1').and_return(contribution)
      end
      it{ should == contribution }
    end

    context "when we have an txn_id that does not return contribution but a parent_txn_id that does" do
      before do
        controller.stub(:params).and_return({'txn_id' => '1', 'parent_txn_id' => '2'})
        PaymentEngine.should_receive(:find_payment).with(payment_id: '1').and_return(nil)
        PaymentEngine.should_receive(:find_payment).with(payment_id: '2').and_return(contribution)
      end
      it{ should == contribution }
    end

    context "when we do not have any id" do
      before do
        controller.stub(:params).and_return({})
        PaymentEngine.should_not_receive(:find_payment)
      end
      it{ should be_nil }
    end

    context "when we have an txn_id" do
      before do
        controller.stub(:params).and_return({'txn_id' => '1'})
        PaymentEngine.should_receive(:find_payment).with(payment_id: '1').and_return(contribution)
      end
      it{ should == contribution }
    end
  end

  describe "#process_paypal_message" do
    subject{ controller.process_paypal_message data }
    let(:data){ {'test_data' => true} }
    before do
      controller.stub(:params).and_return({'contribution_id' => 1})
      PaymentEngine.should_receive(:create_payment_notification).with(contribution_id: contribution.id, extra_data: data)
    end

    context "when data['checkout_status'] == 'PaymentActionCompleted'" do
      let(:data){ {'checkout_status' => 'PaymentActionCompleted'} }
      before do
        contribution.should_receive(:confirm!)
      end
      it("should call confirm"){ subject }
    end

    context "some real data with revert op" do
      let(:data){ { "mc_gross" => "-150.00","protection_eligibility" => "Eligible","payer_id" => "4DK6S6Q75Z5YS","address_street" => "AV. SAO CARLOS, 2205 - conj 501/502 Centro","payment_date" => "09:55:14 Jun 26, 2013 PDT","payment_status" => "Refunded","charset" => "utf-8","address_zip" => "13560-900","first_name" => "Marcius","mc_fee" => "-8.70","address_country_code" => "BR","address_name" => "Marcius Milori","notify_version" => "3.7","reason_code" => "refund","custom" => "","address_country" => "Brazil","address_city" => "São Carlos","verify_sign" => "AbedXpvDaliC7hltYoQrebkEQft7A.y6bRnDvjPIIB1Mct8-aDGcHkcV","payer_email" => "milorimarcius@gmail.com","parent_txn_id" => "78T862320S496750Y","txn_id" => "9RP43514H84299332","payment_type" => "instant","last_name" => "Milori","address_state" => "São Paulo","receiver_email" => "financeiro@catarse.me","payment_fee" => "","receiver_id" => "BVUB4EVC7YCWL","item_name" => "Apoio para o projeto A Caça (La Chasse) no valor de R$ 150","mc_currency" => "BRL","item_number" => "","residence_country" => "BR","handling_amount" => "0.00","transaction_subject" => "Apoio para o projeto A Caça (La Chasse) no valor de R$ 150","payment_gross" => "","shipping" => "0.00","ipn_track_id" => "18c487e6abca4" } }
      before do
        contribution.should_receive(:refund!)
      end
      it("should call refund"){ subject }
    end

    context "when it's a refund message" do
      let(:data){ {'payment_status' => 'refunded'} }
      before do
        contribution.should_receive(:refund!)
      end
      it("should call refund"){ subject }
    end

    context "when it's a completed message" do
      let(:data){ {'payment_status' => 'Completed'} }
      before do
        contribution.should_receive(:confirm!)
      end
      it("should call confirm"){ subject }
    end

    context "when it's a cancelation message" do
      let(:data){ {'payment_status' => 'canceled_reversal'} }
      before do
        contribution.should_receive(:cancel!)
      end
      it("should call cancel"){ subject }
    end

    context "when it's a payment expired message" do
      let(:data){ {'payment_status' => 'expired'} }
      before do
        contribution.should_receive(:pendent!)
      end
      it("should call pendent"){ subject }
    end

    context "all other values of payment_status" do
      let(:data){ {'payment_status' => 'other'} }
      before do
        contribution.should_receive(:waiting!)
      end
      it("should call waiting"){ subject }
    end
  end
end
