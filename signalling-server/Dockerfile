FROM golang:1.22-alpine AS build

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . ./
RUN CGO_ENABLED=0 go build -o /out/signalling-server .

FROM alpine:3.20

RUN adduser -D -g "" -h /app -s /sbin/nologin tojam
WORKDIR /app
COPY --from=build /out/signalling-server /usr/local/bin/signalling-server

EXPOSE 5050
USER tojam
CMD ["/usr/local/bin/signalling-server"]
