package domain

type Requirement struct {
	Description string `json:"description"`
	Priority string `json:"priority"`
	Category string `json:"category"`
}

func NewRequirement(description string, priority string, category string) (Requirement, error) {
	v := Requirement{
		Description: description,
		Priority: priority,
		Category: category,
	}
	return v, nil
}
