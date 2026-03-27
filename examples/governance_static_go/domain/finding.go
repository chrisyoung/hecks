package domain

type Finding struct {
	Category string `json:"category"`
	Severity string `json:"severity"`
	Description string `json:"description"`
}

func NewFinding(category string, severity string, description string) (Finding, error) {
	v := Finding{
		Category: category,
		Severity: severity,
		Description: description,
	}
	return v, nil
}
