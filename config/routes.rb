CatarsePaypalExpress::Engine.routes.draw do
  scope 'paypal_express', controller: 'paypal_express', path: '' do
    get  :review
    post :pay
    get  :success
    get  :cancel
    post :ipn
  end
end
