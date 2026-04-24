package orders

import "testing"

func TestListByTenantFiltersCatalog(t *testing.T) {
	service := NewService()

	orders := service.ListByTenant("tenant-a")
	if len(orders) != 2 {
		t.Fatalf("expected 2 orders for tenant-a, got %d", len(orders))
	}

	for _, order := range orders {
		if order.TenantID != "tenant-a" {
			t.Fatalf("expected tenant-a order, got %s", order.TenantID)
		}
	}
}

func TestFindByIDReturnsMissingForOtherTenant(t *testing.T) {
	service := NewService()

	if _, ok := service.FindByID("tenant-b", "ord-1001"); ok {
		t.Fatal("expected tenant-b to be isolated from tenant-a order")
	}
}
