package domain

type CustomerFacing struct{}

func (s CustomerFacing) SatisfiedBy(Deployment *Deployment) bool {
	return Deployment.Audience == "customer-facing" || Deployment.Audience == "public"
}
