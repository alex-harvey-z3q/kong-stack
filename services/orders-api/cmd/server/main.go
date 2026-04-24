package main

import (
	"log"
	"net/http"
	"os"

	"example.com/kong-stack/orders-api/internal/api"
	"example.com/kong-stack/orders-api/internal/orders"
)

func main() {
	addr := envOrDefault("ORDERS_API_ADDR", ":8080")
	service := orders.NewService()
	handler := api.NewHandler(service)

	log.Printf("orders-api listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatal(err)
	}
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
