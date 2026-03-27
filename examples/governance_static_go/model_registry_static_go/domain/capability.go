package domain

type Capability struct {
	Name string `json:"name"`
	Category string `json:"category"`
}

func NewCapability(name string, category string) (Capability, error) {
	v := Capability{
		Name: name,
		Category: category,
	}
	return v, nil
}
