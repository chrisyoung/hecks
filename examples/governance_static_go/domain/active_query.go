package domain

func Active(repo DeploymentRepository) ([]*Deployment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
