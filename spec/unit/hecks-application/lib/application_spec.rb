# frozen_string_literal: true
describe HecksApplication do
  let(:log_output) {[]}

  subject do
    HecksApplication.new(
      domain:    PizzaBuilder,
      database:  HecksAdapters::MemoryDatabase,
      listeners: [HecksLogger.new(output: log_output)]
    )
  end

  describe '#create' do
    it do
      id = subject[:pizzas].create(PIZZA_ATTRIBUTES).result[:id]
      expect(subject[:pizzas].read(id).name).to eq 'White Pizza'
    end
  end

  describe '#read' do
    it do
      id = subject[:pizzas].create(PIZZA_ATTRIBUTES).result[:id]
      expect(subject[:pizzas].read(id).name).to eq 'White Pizza'
    end
  end

  describe '#update' do
    it do
      id = subject[:pizzas].create(PIZZA_ATTRIBUTES).result[:id]
      res = subject[:pizzas].update(
        PIZZA_ATTRIBUTES.merge(
          id:   id,
          name: "Green Pizza"
        )
      )
      expect(subject[:pizzas].read(id).name).to eq 'Green Pizza'
    end
  end

  describe '#delete' do
    it do
      id = subject[:pizzas].create(PIZZA_ATTRIBUTES).result[:id]
      subject[:pizzas].delete(id)
      expect(subject[:pizzas].read(id)).to eq nil
    end
  end

  describe '#call' do
    it 'Runs a command' do
      result = subject.call(
        command_name: :create,
        module_name:  :pizzas,
        args:         PIZZA_ATTRIBUTES
      ).result

      expect(
        subject.query(
          query_name:  :find_by_id,
          module_name: :pizzas,
          args:        { id: result[:id] }
        ).name
      ).to eq 'White Pizza'
    end

    it 'Broadcasts events' do
      subject.call(
        command_name: :create,
        module_name:  :pizzas,
        args:         PIZZA_ATTRIBUTES
      )
      expect(log_output.first).to include('pizzas_create')
    end
  end
end
