package domain

func ByEnvironment(repo DeploymentRepository, env string) ([]*Deployment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Deployment
	for _, item := range all {
		if item.Environment == env {
			results = append(results, item)
		}
	}
	return results, nil
}
