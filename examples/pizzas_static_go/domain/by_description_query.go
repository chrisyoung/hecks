package domain

// ByDescription query for Pizza
// Generated from DSL query definition
func ByDescription(repo PizzaRepository) ([]*Pizza, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Pizza
	for _, item := range all {
		// TODO: filter logic from DSL block
		results = append(results, item)
	}
	return results, nil
}
