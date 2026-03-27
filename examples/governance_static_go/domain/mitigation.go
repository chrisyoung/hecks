package domain

type Mitigation struct {
	FindingCategory string `json:"finding_category"`
	Action string `json:"action"`
	Status string `json:"status"`
}

func NewMitigation(findingCategory string, action string, status string) (Mitigation, error) {
	v := Mitigation{
		FindingCategory: findingCategory,
		Action: action,
		Status: status,
	}
	return v, nil
}
