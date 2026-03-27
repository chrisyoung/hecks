package domain

func ByDescription(repo PizzaRepository, desc string) ([]*Pizza, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Pizza
	for _, item := range all {
		if item.Description == desc {
			results = append(results, item)
		}
	}
	return results, nil
}
