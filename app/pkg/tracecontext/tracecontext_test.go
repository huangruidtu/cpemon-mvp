package tracecontext

import (
	"context"
	"net/http"
	"testing"
)

func TestFromHTTPHeaderUsesTraceparent(t *testing.T) {
	header := http.Header{}
	header.Set(TraceparentHeader, "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")

	traceID, traceparent := FromHTTPHeader(header)
	if traceID != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Fatalf("traceID=%q", traceID)
	}
	if traceparent != "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01" {
		t.Fatalf("traceparent=%q", traceparent)
	}
}

func TestFromHTTPHeaderFallsBackToTraceIDHeader(t *testing.T) {
	header := http.Header{}
	header.Set(TraceIDHeader, "4bf92f3577b34da6a3ce929d0e0e4736")

	traceID, traceparent := FromHTTPHeader(header)
	if traceID != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Fatalf("traceID=%q", traceID)
	}
	if len(traceparent) != 55 {
		t.Fatalf("traceparent length=%d", len(traceparent))
	}
}

func TestContextRoundTrip(t *testing.T) {
	ctx := WithTrace(context.Background(), "4bf92f3577b34da6a3ce929d0e0e4736", "tp")
	if TraceID(ctx) != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Fatalf("traceID=%q", TraceID(ctx))
	}
	if Traceparent(ctx) != "tp" {
		t.Fatalf("traceparent=%q", Traceparent(ctx))
	}
}
