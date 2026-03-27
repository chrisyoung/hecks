package domain

import "time"

type AddTopping struct {
	PizzaId string `json:"pizza_id"`
	Name string `json:"name"`
	Amount int64 `json:"amount"`
}

func (c AddTopping) CommandName() string { return "AddTopping" }

func (c AddTopping) Execute(repo PizzaRepository) (*Pizza, *AddedTopping, error) {
	existing, err := repo.Find(c.PizzaId)
	if err != nil {
		return nil, nil, err
	}
	if existing == nil {
		return nil, nil, fmt.Errorf("Pizza not found: %s", c.PizzaId)
	}
	existing.Name = c.Name
	existing.Amount = c.Amount
	existing.UpdatedAt = time.Now()
	if err := existing.Validate(); err != nil {
		return nil, nil, err
	}
	if err := repo.Save(existing); err != nil {
		return nil, nil, err
	}
	event := AddedTopping{
		AggregateID: existing.ID,
		PizzaId: c.PizzaId,
		Name: c.Name,
		Amount: c.Amount,
		OccurredAt: time.Now(),
	}
	return existing, &event, nil
}
