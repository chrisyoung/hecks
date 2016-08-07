module PizzaHexagon::Domain::Pizzas::UseCases
  class CreatePizza
    attr_accessor :args, :id

    def initialize(args:, database_adapter:, validators: [Validator.new])
      @args       = args
      @database_adapter = database_adapter
      @validators = validators
    end

    def call(use_case=nil)
      validate
      create
      self
    end

    def errors
      @errors = validators.flat_map { |validator| validator.errors }
    end

    private

    attr_accessor :database_adapter, :validators, :args

    def validate
      validators.each do |validator|
        validator.call(self)
      end
    end

    def create
      return unless errors.empty?
      @id = database_adapter[:pizzas].create(name: args[:name])
    end
  end
end
