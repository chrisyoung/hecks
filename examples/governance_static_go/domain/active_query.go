package domain

func Active(repo DeploymentRepository) ([]*Deployment, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Deployment
	for _, item := range all {
		if item.Status == "deployed" {
			results = append(results, item)
		}
	}
	return results, nil
}
