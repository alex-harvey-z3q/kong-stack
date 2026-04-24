FROM golang:1.25 AS build

WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/orders-api ./cmd/server

FROM gcr.io/distroless/static-debian12

COPY --from=build /out/orders-api /orders-api

EXPOSE 8080

ENTRYPOINT ["/orders-api"]

