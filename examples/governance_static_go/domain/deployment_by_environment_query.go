package domain

func DeploymentByEnvironment(repo DeploymentRepository, env string) ([]*Deployment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
