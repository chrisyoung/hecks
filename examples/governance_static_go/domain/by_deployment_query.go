package domain

func ByDeployment(repo MonitoringRepository, deployment_id string) ([]*Monitoring, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
