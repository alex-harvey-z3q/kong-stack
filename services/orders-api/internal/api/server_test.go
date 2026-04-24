package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/kong-stack/orders-api/internal/orders"
)

func TestListOrdersUsesTenantHeader(t *testing.T) {
	handler := NewHandler(orders.NewService())

	request := httptest.NewRequest(http.MethodGet, "/v1/orders", nil)
	request.Header.Set("X-Tenant-ID", "tenant-b")
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", recorder.Code)
	}

	var body struct {
		TenantID string         `json:"tenantId"`
		Orders   []orders.Order `json:"orders"`
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if body.TenantID != "tenant-b" {
		t.Fatalf("expected tenant-b, got %s", body.TenantID)
	}

	if len(body.Orders) != 1 || body.Orders[0].ID != "ord-2001" {
		t.Fatalf("unexpected tenant-b payload: %+v", body.Orders)
	}
}

func TestGetCallerReturnsGatewayIdentity(t *testing.T) {
	handler := NewHandler(orders.NewService())

	request := httptest.NewRequest(http.MethodGet, "/v1/caller", nil)
	request.Header.Set("X-Consumer-Username", "partner-app")
	request.Header.Set("X-Authenticated-Scope", "orders:read,orders:write")
	request.Header.Set("X-Client-Cert-Subject", "CN=partner-app,O=Example Corp")
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", recorder.Code)
	}

	var body map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if body["consumer"] != "partner-app" {
		t.Fatalf("expected partner-app consumer, got %v", body["consumer"])
	}
}

func TestGetOrderReturnsNotFoundForWrongTenant(t *testing.T) {
	handler := NewHandler(orders.NewService())

	request := httptest.NewRequest(http.MethodGet, "/v1/orders/ord-1001", nil)
	request.Header.Set("X-Tenant-ID", "tenant-b")
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", recorder.Code)
	}
}
