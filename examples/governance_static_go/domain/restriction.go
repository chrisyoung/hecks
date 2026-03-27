package domain

type Restriction struct {
	Type string `json:"type"`
	Description string `json:"description"`
}

func NewRestriction(typeVal string, description string) (Restriction, error) {
	v := Restriction{
		Type: typeVal,
		Description: description,
	}
	return v, nil
}
