package domain

type IntendedUse struct {
	Description string `json:"description"`
	Domain string `json:"domain"`
}

func NewIntendedUse(description string, domain string) (IntendedUse, error) {
	v := IntendedUse{
		Description: description,
		Domain: domain,
	}
	return v, nil
}
