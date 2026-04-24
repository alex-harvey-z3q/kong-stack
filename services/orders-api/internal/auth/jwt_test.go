package auth

import (
	"net/http"
	"reflect"
	"testing"
)

func TestIdentityFromHeaders(t *testing.T) {
	headers := http.Header{
		"X-Consumer-Username":   []string{"partner-app"},
		"X-Authenticated-Scope": []string{"orders:read orders:write"},
		"X-Client-Cert-Subject": []string{"CN=partner-app,O=Example Corp"},
	}

	identity := IdentityFromHeaders(headers)

	if identity.Consumer != "partner-app" {
		t.Fatalf("expected consumer partner-app, got %s", identity.Consumer)
	}

	expectedScopes := []string{"orders:read", "orders:write"}
	if !reflect.DeepEqual(identity.Scopes, expectedScopes) {
		t.Fatalf("expected scopes %v, got %v", expectedScopes, identity.Scopes)
	}

	if identity.ClientCertificateSubject != "CN=partner-app,O=Example Corp" {
		t.Fatalf("unexpected certificate subject: %s", identity.ClientCertificateSubject)
	}
}

func TestIdentityFallsBackToAnonymous(t *testing.T) {
	identity := IdentityFromHeaders(http.Header{})

	if identity.Consumer != "anonymous" {
		t.Fatalf("expected anonymous consumer, got %s", identity.Consumer)
	}

	if len(identity.Scopes) != 0 {
		t.Fatalf("expected no scopes, got %v", identity.Scopes)
	}
}
