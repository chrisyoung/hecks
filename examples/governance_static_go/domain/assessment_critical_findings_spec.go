package domain

type AssessmentCriticalFindings struct{}

func (s AssessmentCriticalFindings) SatisfiedBy(Assessment *Assessment) bool {
	return true // TODO: translate predicate
}
