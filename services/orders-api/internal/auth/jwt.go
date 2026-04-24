package auth

import (
	"net/http"
	"strings"
)

type Identity struct {
	Consumer                 string   `json:"consumer"`
	Scopes                   []string `json:"scopes"`
	ClientCertificateSubject string   `json:"clientCertificateSubject"`
}

func IdentityFromHeaders(headers http.Header) Identity {
	consumer := firstNonEmpty(
		headers.Get("X-Consumer-Username"),
		headers.Get("X-Authenticated-Userid"),
		"anonymous",
	)

	clientCertSubject := firstNonEmpty(
		headers.Get("X-Client-Cert-Subject"),
		"not-present",
	)

	return Identity{
		Consumer:                 consumer,
		Scopes:                   splitScopes(headers.Get("X-Authenticated-Scope")),
		ClientCertificateSubject: clientCertSubject,
	}
}

func splitScopes(raw string) []string {
	if raw == "" {
		return []string{}
	}

	parts := strings.FieldsFunc(raw, func(r rune) bool {
		return r == ' ' || r == ','
	})

	scopes := make([]string, 0, len(parts))
	for _, part := range parts {
		if part != "" {
			scopes = append(scopes, part)
		}
	}

	return scopes
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
