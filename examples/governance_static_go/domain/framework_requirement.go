package domain

type FrameworkRequirement struct {
	Article string `json:"article"`
	Section string `json:"section"`
	Description string `json:"description"`
	RiskCategory string `json:"risk_category"`
}

func NewFrameworkRequirement(article string, section string, description string, riskCategory string) (FrameworkRequirement, error) {
	v := FrameworkRequirement{
		Article: article,
		Section: section,
		Description: description,
		RiskCategory: riskCategory,
	}
	return v, nil
}
