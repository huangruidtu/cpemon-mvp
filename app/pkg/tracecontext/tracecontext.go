package tracecontext

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"regexp"
	"strings"
)

type contextKey string

const (
	traceIDKey        contextKey = "trace_id"
	traceparentKey    contextKey = "traceparent"
	TraceparentHeader            = "traceparent"
	TraceIDHeader                = "X-Trace-Id"
)

var traceparentPattern = regexp.MustCompile(`^[\da-f]{2}-([\da-f]{32})-[\da-f]{16}-[\da-f]{2}$`)

func FromHTTPHeader(header http.Header) (string, string) {
	traceparent := strings.ToLower(strings.TrimSpace(header.Get(TraceparentHeader)))
	if matches := traceparentPattern.FindStringSubmatch(traceparent); len(matches) == 2 {
		return matches[1], traceparent
	}

	traceID := normalizeTraceID(header.Get(TraceIDHeader))
	if traceID == "" {
		traceID = newTraceID()
	}
	return traceID, NewTraceparent(traceID)
}

func WithTrace(ctx context.Context, traceID, traceparent string) context.Context {
	ctx = context.WithValue(ctx, traceIDKey, traceID)
	return context.WithValue(ctx, traceparentKey, traceparent)
}

func TraceID(ctx context.Context) string {
	if v, ok := ctx.Value(traceIDKey).(string); ok {
		return v
	}
	return ""
}

func Traceparent(ctx context.Context) string {
	if v, ok := ctx.Value(traceparentKey).(string); ok {
		return v
	}
	traceID := TraceID(ctx)
	if traceID == "" {
		traceID = newTraceID()
	}
	return NewTraceparent(traceID)
}

func NewTraceparent(traceID string) string {
	spanID := randomHex(8)
	return "00-" + normalizeTraceID(traceID) + "-" + spanID + "-01"
}

func normalizeTraceID(value string) string {
	cleaned := strings.ToLower(strings.TrimSpace(value))
	cleaned = strings.ReplaceAll(cleaned, "-", "")
	if len(cleaned) != 32 {
		return ""
	}
	for _, r := range cleaned {
		if (r < '0' || r > '9') && (r < 'a' || r > 'f') {
			return ""
		}
	}
	if cleaned == "00000000000000000000000000000000" {
		return ""
	}
	return cleaned
}

func newTraceID() string {
	return randomHex(16)
}

func randomHex(size int) string {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return strings.Repeat("0", size*2)
	}
	return hex.EncodeToString(buf)
}
