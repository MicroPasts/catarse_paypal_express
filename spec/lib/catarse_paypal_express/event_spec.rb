require 'spec_helper'

describe CatarsePaypalExpress::Event do
  subject { described_class.new(contribution, data.with_indifferent_access) }
  let(:contribution) { double('Contribution', id: 333, pending?: true) }

  describe '#process' do
    before do
      expect(PaymentEngine).to receive(:create_payment_notification).
        with('resource_id' => { 'contribution_id' => contribution.id }, 'extra_data' => data)
    end

    context "when data['checkout_status'] == 'PaymentActionCompleted'" do
      before do
        expect(contribution).to receive(:confirm!)
      end
      let(:data) do
        {
          'checkout_status' => 'PaymentActionCompleted',
          'resource_id'     => { 'contribution_id' => contribution.id }
        }
      end

      it 'should call confirm' do
        subject.process
      end
    end

    context "some real data with revert op" do
      before do
        expect(contribution).to receive(:refund!)
      end
      let(:data) do
        {
          "mc_gross" => "-150.00",
          "protection_eligibility" => "Eligible",
          "payer_id" => "4DK6S6Q75Z5YS",
          "address_street" => "AV. SAO CARLOS, 2205 - conj 501/502 Centro",
          "payment_date" => "09:55:14 Jun 26, 2013 PDT",
          "payment_status" => "Refunded",
          "charset" => "utf-8",
          "address_zip" => "13560-900",
          "first_name" => "Marcius",
          "mc_fee" => "-8.70",
          "address_country_code" => "BR",
          "address_name" => "Marcius Milori",
          "notify_version" => "3.7",
          "reason_code" => "refund",
          "custom" => "",
          "address_country" => "Brazil",
          "address_city" => "São Carlos",
          "verify_sign" => "AbedXpvDaliC7hltYoQrebkEQft7A.y6bRnDvjPIIB1Mct8-aDGcHkcV",
          "payer_email" => "milorimarcius@gmail.com",
          "parent_txn_id" => "78T862320S496750Y",
          "txn_id" => "9RP43514H84299332",
          "payment_type" => "instant",
          "last_name" => "Milori",
          "address_state" => "São Paulo",
          "receiver_email" => "financeiro@catarse.me",
          "payment_fee" => "",
          "receiver_id" => "BVUB4EVC7YCWL",
          "item_name" => "Apoio para o projeto A Caça (La Chasse) no valor de R$ 150",
          "mc_currency" => "BRL",
          "item_number" => "",
          "residence_country" => "BR",
          "handling_amount" => "0.00",
          "transaction_subject" => "Apoio para o projeto A Caça (La Chasse) no valor de R$ 150",
          "payment_gross" => "",
          "shipping" => "0.00",
          "ipn_track_id" => "18c487e6abca4",
          'resource_id' => { 'contribution_id' => contribution.id }
        }
      end

      it 'should call refund' do
        subject.process
      end
    end

    context "when it's a refund message" do
      before do
        expect(contribution).to receive(:refund!)
      end
      let(:data) do
        {
          'payment_status' => 'refunded',
          'resource_id'    => { 'contribution_id' => contribution.id }
        }
      end

      it 'should call refund' do
        subject.process
      end
    end

    context "when it's a completed message" do
      before do
        expect(contribution).to receive(:confirm!)
      end
      let(:data) do
        {
          'payment_status' => 'Completed',
          'resource_id'    => { 'contribution_id' => contribution.id }
        }
      end

      it 'should call confirm' do
        subject.process
      end
    end

    context "when it's a cancelation message" do
      before do
        expect(contribution).to receive(:cancel!)
      end
      let(:data) do
        {
          'payment_status' => 'canceled_reversal',
          'resource_id'    => { 'contribution_id' => contribution.id }
        }
      end

      it 'should call cancel' do
        subject.process
      end
    end

    context "when it's a payment expired message" do
      before do
        expect(contribution).to receive(:pendent!)
      end
      let(:data) do
        {
          'payment_status' => 'expired',
          'resource_id'    => { 'contribution_id' => contribution.id }
        }
      end

      it 'should call pendent' do
        subject.process
      end
    end

    context "all other values of payment_status" do
      before do
        expect(contribution).to receive(:wait_confirmation!)
      end
      let(:data) do
        {
          'payment_status' => 'other',
          'resource_id'    => { 'contribution_id' => contribution.id }
        }
      end

      it 'should call waiting' do
        subject.process
      end
    end
  end
end
