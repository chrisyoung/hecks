class OrdersController < ApplicationController
  def index
    @orders = Order.all
    @pizzas = Pizza.all
    @pricing = PricingConfig.all.first
  end

  def create
    toppings = Array(params[:toppings]).reject(&:blank?).join(",")
    @order = Order.place(
      pizza_id: params[:pizza_id],
      quantity: params[:quantity].to_i,
      extra_toppings: toppings.presence
    )
    @pizzas = Pizza.all
    @pricing = PricingConfig.all.first

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to orders_path }
    end
  rescue PizzasDomain::ValidationError => e
    redirect_to orders_path, alert: e.message
  end

  def cancel
    Order.cancel_order(pizza_id: params[:id])
    @order_id = params[:id]

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to orders_path }
    end
  end
end
