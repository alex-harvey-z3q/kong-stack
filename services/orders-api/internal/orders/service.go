package orders

type Order struct {
	ID          string `json:"id"`
	TenantID    string `json:"tenantId"`
	Status      string `json:"status"`
	AmountCents int    `json:"amountCents"`
	Currency    string `json:"currency"`
}

type Service struct {
	catalog []Order
}

func NewService() *Service {
	return &Service{
		catalog: []Order{
			{ID: "ord-1001", TenantID: "tenant-a", Status: "paid", AmountCents: 12500, Currency: "USD"},
			{ID: "ord-1002", TenantID: "tenant-a", Status: "shipped", AmountCents: 4200, Currency: "USD"},
			{ID: "ord-2001", TenantID: "tenant-b", Status: "pending", AmountCents: 9900, Currency: "AUD"},
		},
	}
}

func (s *Service) ListByTenant(tenantID string) []Order {
	if tenantID == "" {
		tenantID = "tenant-a"
	}

	orders := make([]Order, 0, len(s.catalog))
	for _, order := range s.catalog {
		if order.TenantID == tenantID {
			orders = append(orders, order)
		}
	}

	return orders
}

func (s *Service) FindByID(tenantID, orderID string) (Order, bool) {
	for _, order := range s.ListByTenant(tenantID) {
		if order.ID == orderID {
			return order, true
		}
	}

	return Order{}, false
}
