package domain

func DeploymentByModel(repo DeploymentRepository, model_id string) ([]*Deployment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
