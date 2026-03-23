class OrdersController < ApplicationController
  def index
    if params[:status] == "pending"
      @orders = Order.pending
    else
      @orders = Order.all
    end
  end

  def new
    @pizza = Pizza.find(params[:pizza_id])
    redirect_to pizzas_path, alert: "Pizza not found" unless @pizza
    @order = Order.new(pizza_id: @pizza.id, quantity: nil, status: nil)
  end

  def create
    @order = Order.place(
      pizza_id: order_params[:pizza_id],
      quantity: order_params[:quantity].to_i
    )
    redirect_to orders_path, notice: "Order placed!"
  end

  private

  def order_params
    params.require(:order).permit(:pizza_id, :quantity)
  end
end
