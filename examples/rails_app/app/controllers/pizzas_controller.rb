class PizzasController < ApplicationController
  def index
    if params[:description].present?
      @pizzas = Pizza.by_description(params[:description])
    else
      @pizzas = Pizza.all
    end
  end

  def show
    @pizza = Pizza.find(params[:id])
    redirect_to pizzas_path, alert: "Pizza not found" unless @pizza
  end

  def new
    @pizza = Pizza.new(name: nil, description: nil)
  end

  def create
    @pizza = Pizza.create(
      name: pizza_params[:name],
      description: pizza_params[:description]
    )
    redirect_to pizza_path(@pizza), notice: "Pizza created!"
  rescue PizzasDomain::ValidationError => e
    @pizza = Pizza.new(name: nil, description: nil)
    @pizza.errors.add(:base, e.message)
    render :new, status: :unprocessable_entity
  end

  def edit
    @pizza = Pizza.find(params[:id])
    redirect_to pizzas_path, alert: "Pizza not found" unless @pizza
  end

  def update
    Pizza.delete(params[:id])
    @pizza = Pizza.update(
      pizza_id: params[:id],
      name: pizza_params[:name],
      description: pizza_params[:description]
    )
    redirect_to pizza_path(@pizza), notice: "Pizza updated!"
  rescue PizzasDomain::ValidationError => e
    @pizza = Pizza.find(params[:id]) || Pizza.new(name: nil, description: nil)
    @pizza.errors.add(:base, e.message)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Pizza.delete(params[:id])
    redirect_to pizzas_path, notice: "Pizza deleted."
  end

  private

  def pizza_params
    params.require(:pizza).permit(:name, :description)
  end
end
