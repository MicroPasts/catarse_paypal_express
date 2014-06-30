CatarsePaypalExpress::Engine.routes.draw do
  scope 'paypal_express', controller: 'paypal_express', path: '' do
    get  :review
    post :pay
    get  :success
    get  :cancel
  end

  resources :paypal_express, only: [], path: 'payment/paypal_express' do
    collection do
      post :ipn
    end
  end
end

