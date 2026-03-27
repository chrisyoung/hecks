package domain

const (
	OrderStatusPending = "pending"
	OrderStatusCancelled = "cancelled"
)

func (a *Order) IsPending() bool { return a.Status == OrderStatusPending }
func (a *Order) IsCancelled() bool { return a.Status == OrderStatusCancelled }

func (a *Order) ValidTransition(target string) bool {
	switch {
	case target == "cancelled": return true
	default: return false
	}
}
