package main

import (
	"context"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

var (
	wsConnections    metric.Int64UpDownCounter
	wsMessageLatency metric.Float64Histogram
)

func InitMetrics(ctx context.Context) (func(), error) {
	exporter, err := otlpmetrichttp.New(ctx)
	if err != nil {
		return nil, err
	}

	res, _ := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("websocket-gateway"),
		),
	)

	provider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exporter,
			sdkmetric.WithInterval(10*time.Second),
		)),
	)
	otel.SetMeterProvider(provider)

	meter := provider.Meter("websocket-gateway")

	wsConnections, _ = meter.Int64UpDownCounter("ws.connections_active",
		metric.WithDescription("Currently active WebSocket connections"))
	wsMessageLatency, _ = meter.Float64Histogram("ws.broadcast_latency",
		metric.WithDescription("Time to broadcast a message in ms"),
		metric.WithExplicitBucketBoundaries(0.001, 0.005, 0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 5.0),
	)

	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		provider.Shutdown(ctx)
	}, nil
}
