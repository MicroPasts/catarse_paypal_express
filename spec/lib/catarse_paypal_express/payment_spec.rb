require 'spec_helper'

describe CatarsePaypalExpress::Payment do
  subject { described_class.new(payable_resource, {}) }
  let(:payable_resource) { Contribution.new }

  describe '#gateway' do
    before do
      allow(subject).to       receive(:gateway).and_call_original
      allow(PaymentEngine).to receive(:configuration).and_return(paypal_config)
    end

    context 'when we have the paypal configuration' do
      let(:paypal_config) do
        {
          paypal_password:  'pass',
          paypal_signature: 'signature',
          paypal_username:  'username'
        }
      end

      it 'returns an instance of PaypalExpressGateway' do
        allow(ActiveMerchant::Billing::PaypalExpressGateway).to receive(:new).with(
          login:     PaymentEngine.configuration[:paypal_username],
          password:  PaymentEngine.configuration[:paypal_password],
          signature: PaymentEngine.configuration[:paypal_signature]
        ).and_return('gateway instance')
        expect(subject.gateway).to eql('gateway instance')
      end
    end

    context 'when we do not have the paypal configuration' do
      let(:paypal_config) { {} }

      it 'returns nil' do
        expect(subject.gateway).to be_nil
      end
    end
  end
end
