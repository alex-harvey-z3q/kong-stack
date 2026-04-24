package api

import (
	"encoding/json"
	"net/http"

	"example.com/kong-stack/orders-api/internal/auth"
	"example.com/kong-stack/orders-api/internal/orders"
)

type Server struct {
	orders *orders.Service
}

func NewHandler(orderService *orders.Service) http.Handler {
	server := &Server{orders: orderService}
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", server.handleHealth)
	mux.HandleFunc("GET /v1/orders", server.handleListOrders)
	mux.HandleFunc("GET /v1/orders/{orderID}", server.handleGetOrder)
	mux.HandleFunc("GET /v1/caller", server.handleCaller)

	return mux
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleListOrders(w http.ResponseWriter, r *http.Request) {
	tenantID := tenantFromRequest(r)
	writeJSON(w, http.StatusOK, map[string]any{
		"tenantId": tenantID,
		"orders":   s.orders.ListByTenant(tenantID),
	})
}

func (s *Server) handleGetOrder(w http.ResponseWriter, r *http.Request) {
	tenantID := tenantFromRequest(r)
	orderID := r.PathValue("orderID")

	order, ok := s.orders.FindByID(tenantID, orderID)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "order not found"})
		return
	}

	writeJSON(w, http.StatusOK, order)
}

func (s *Server) handleCaller(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, auth.IdentityFromHeaders(r.Header))
}

func tenantFromRequest(r *http.Request) string {
	if tenantID := r.Header.Get("X-Tenant-ID"); tenantID != "" {
		return tenantID
	}
	return "tenant-a"
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
