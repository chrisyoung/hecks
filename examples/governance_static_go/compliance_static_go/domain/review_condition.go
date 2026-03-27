package domain

type ReviewCondition struct {
	Requirement string `json:"requirement"`
	Met string `json:"met"`
	Evidence string `json:"evidence"`
}

func NewReviewCondition(requirement string, met string, evidence string) (ReviewCondition, error) {
	v := ReviewCondition{
		Requirement: requirement,
		Met: met,
		Evidence: evidence,
	}
	return v, nil
}
