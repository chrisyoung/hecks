class Admin::PizzasController < ApplicationController
  def index
    @pizzas = Pizza.all
    @pricing = PricingConfig.all.first
  end

  def create
    @pizza = Pizza.create(
      name: params[:name],
      description: params[:description],
      price: params[:price].to_i
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_pizzas_path }
    end
  rescue PizzasDomain::ValidationError => e
    redirect_to admin_pizzas_path, alert: e.message
  end

  def update_pricing
    config = PricingConfig.all.first
    if config
      PricingConfig.set_extra_topping_price(
        pricing_config_id: config.id,
        extra_topping_price: params[:extra_topping_price].to_i
      )
    else
      PricingConfig.create(extra_topping_price: params[:extra_topping_price].to_i)
    end
    redirect_to admin_pizzas_path
  end

  def add_topping
    @pizza_id = params[:id]
    @topping_name = params[:topping_name]
    Pizza.add_topping(pizza_id: @pizza_id, topping: @topping_name)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_pizzas_path }
    end
  end

  def destroy
    @pizza_id = params[:id]
    Pizza.delete(@pizza_id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_pizzas_path }
    end
  end
end
